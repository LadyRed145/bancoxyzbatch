#!/usr/bin/env bash
# BancoXYZ EFT S9 - Corrige la doble ejecucion de schema.sql por Spring SQL init.
# Seguro, idempotente; NO elimina ni reescribe datos, CSV ni volumenes.
# Ejecutar con bash desde raiz del repositorio (compatible con terminal Fish).
set -Eeuo pipefail

if [[ -f 'Semana 9/pagos-service/pom.xml' && -f 'docker-compose.yml' ]]; then
  ROOT="$PWD"
else
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
fi
cd "$ROOT"

APP='Semana 9/pagos-service/src/main/resources/application.properties'
CSV_DIR='Semana 9/batch-service/src/main/resources/data'
[[ -f "$APP" ]] || { echo "ERROR: no existe $APP" >&2; exit 2; }
[[ -d "$CSV_DIR" ]] || { echo "ERROR: no existe $CSV_DIR" >&2; exit 2; }
for tool in docker python3 sha256sum; do
  command -v "$tool" >/dev/null || { echo "ERROR: falta $tool" >&2; exit 2; }
done
for file in movimientos_financieros_diarios.csv intereses_trimestrales.csv estados_financieros_anuales.csv; do
  [[ -f "$CSV_DIR/$file" ]] || { echo "ERROR: falta CSV $file" >&2; exit 2; }
done
CSV_ANTES="$(sha256sum "$CSV_DIR"/*.csv)"

echo '== 1/4 Validando PostgreSQL y la migracion existente (solo lectura) =='
docker compose config --quiet
DB="$(docker compose exec -T postgres sh -c 'printf %s "$POSTGRES_DB"')"
if [[ "$DB" != 'bancoxyz' ]]; then
  echo "ERROR: PostgreSQL apunta a '$DB' en vez de bancoxyz. No se cambia nada." >&2
  exit 3
fi
ESTADO="$(docker compose exec -T postgres sh -c 'exec psql -X -v ON_ERROR_STOP=1 -At -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<'SQL'
SELECT CASE WHEN to_regclass('public.pagos_solicitudes') IS NOT NULL
             AND to_regclass('public.pagos_saldos') IS NOT NULL
             AND to_regclass('public.pagos_movimientos') IS NOT NULL
            THEN 'OK' ELSE 'FALTAN_TABLAS' END;
SQL
)"
if [[ "$ESTADO" != 'OK' ]]; then
  echo "ERROR: migracion de Pagos incompleta: $ESTADO. No se arranca ni reescribe el servicio." >&2
  exit 3
fi
echo 'OK: las tres tablas de Pagos ya existen en bancoxyz. No se aplica SQL.'

echo '== 2/4 Deshabilitando SOLO la reinicializacion SQL de Pagos =='
python3 - "$APP" <<'PY'
from pathlib import Path
import os, sys, tempfile
p = Path(sys.argv[1])
content = p.read_text(encoding='utf-8')
lines = content.splitlines(keepends=True)
matches = [i for i, line in enumerate(lines) if line.strip().startswith('spring.sql.init.mode=')]
if len(matches) != 1:
    raise SystemExit('ERROR: se esperaba una sola propiedad spring.sql.init.mode. Archivo intacto.')
i = matches[0]
old = lines[i].strip()
if old == 'spring.sql.init.mode=never':
    print('SIN CAMBIOS: inicializacion Spring SQL ya deshabilitada.')
elif old == 'spring.sql.init.mode=always':
    # PostgreSQL ya ejecuto las migraciones. ScriptUtils no soporta
    # correctamente el DO $migration$ ... END con separadores ';'.
    lines[i] = lines[i].replace('spring.sql.init.mode=always', 'spring.sql.init.mode=never')
    fd, tmp = tempfile.mkstemp(prefix='.pagos_config_', dir=p.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='') as handle:
            handle.write(''.join(lines))
        os.chmod(tmp, p.stat().st_mode & 0o777)
        os.replace(tmp, p)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    print('CORREGIDO: spring.sql.init.mode=never (solo pagos-service).')
else:
    raise SystemExit(f'ERROR: valor no esperado: {old!r}. Archivo intacto.')
PY

echo '== 3/4 Reconstruyendo y validando SOLO pagos-service =='
CID="$(docker compose ps -a -q pagos-service 2>/dev/null || true)"
ACTUAL=''
if [[ -n "$CID" ]]; then
  ACTUAL="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CID" 2>/dev/null || true)"
fi
# Si ya esta healthy con la configuracion instalada, no es necesario reiniciarlo.
# En el caso habitual (salud fallida) se reconstruye solo Pagos.
if [[ "$ACTUAL" == healthy ]]; then
  echo 'OK: pagos-service ya esta HEALTHY. No se reinicia.'
else
  docker compose up -d --no-deps --build pagos-service
fi

CID="$(docker compose ps -a -q pagos-service)"
[[ -n "$CID" ]] || { echo 'ERROR: no se encontro el contenedor de pagos.' >&2; exit 4; }
SALUD=''
for intento in {1..30}; do
  SALUD="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CID" 2>/dev/null || true)"
  if [[ "$SALUD" == healthy ]]; then break; fi
  if [[ "$SALUD" == exited || "$SALUD" == dead ]]; then break; fi
  sleep 3
done

if [[ "$SALUD" != healthy ]]; then
  echo "ERROR: pagos-service no esta HEALTHY (estado: ${SALUD:-desconocido})." >&2
  echo '== Estado real del contenedor =='
  docker compose ps -a pagos-service || true
  echo '== Ultimos registros de la aplicacion (para encontrar causa exacta) =='
  docker compose logs --no-color --tail=100 pagos-service || true
  echo '== Ultimas pruebas del HEALTHCHECK =='
  docker inspect -f '{{if .State.Health}}{{range .State.Health.Log}}{{.ExitCode}}: {{.Output}}{{println}}{{end}}{{end}}' "$CID" 2>/dev/null || true
  exit 4
fi

echo '== 4/4 Verificando endpoints, persistencia y CSV =='
if ! docker compose exec -T pagos-service sh -c 'curl -fsS http://127.0.0.1:${PAGOS_SERVICE_PORT:-8094}/actuator/health'; then
  echo 'ERROR: Docker informa HEALTHY pero el endpoint de salud no responde.' >&2
  exit 4
fi
[[ "$CSV_ANTES" == "$(sha256sum "$CSV_DIR"/*.csv)" ]] || {
  echo 'ERROR: SHA256 de CSV cambió durante la operacion.' >&2
  exit 9
}
echo
echo 'OK REAL: pagos-service HEALTHY; migracion persistida; 3 CSV intactos.'
echo 'NO se ejecutaron Jobs Batch, DROP, TRUNCATE ni operaciones monetarias HTTP.'
echo 'PENDIENTE para cierre total: prueba HTTP JWT con cuentas de laboratorio.'
