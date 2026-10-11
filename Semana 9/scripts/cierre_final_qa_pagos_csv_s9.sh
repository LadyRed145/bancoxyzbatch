#!/usr/bin/env bash
# BancoXYZ S9: corrige la respuesta HTTP de errores en Pagos, valida pagos reales
# de laboratorio con JWT y reejecuta los CSV para confirmar idempotencia Batch.
# Invocacion compatible con Fish: bash este_script.sh [--limpiar-target]
# No crea backups, no cambia CSV, no borra BD/tablas/volumenes/snapshots.
set -Eeuo pipefail

if [[ -f 'Semana 9/pagos-service/pom.xml' && -f 'docker-compose.yml' ]]; then
    :
else
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
    cd -- "$SCRIPT_DIR/../.."
fi
[[ -f 'Semana 9/pagos-service/pom.xml' && -f 'docker-compose.yml' ]] || { echo 'ERROR: ejecuta desde la raiz de bancoxyzbatch.' >&2; exit 2; }

LIMPIAR=0
for arg in "$@"; do
    case "$arg" in
      --limpiar-target) LIMPIAR=1 ;;
      *) echo "Opcion desconocida: $arg" >&2; exit 2 ;;
    esac
done

for tool in python3 bash mvn docker sha256sum; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: no existe $tool" >&2; exit 2; }
done

CSV_DIR='Semana 9/batch-service/src/main/resources/data'
CSV_FILES=(movimientos_financieros_diarios.csv intereses_trimestrales.csv estados_financieros_anuales.csv)
declare -A CSV_HASH
for f in "${CSV_FILES[@]}"; do
    [[ -s "$CSV_DIR/$f" && ! -L "$CSV_DIR/$f" ]] || { echo "ERROR: CSV invalido: $f" >&2; exit 2; }
    CSV_HASH[$f]="$(sha256sum "$CSV_DIR/$f" | cut -d' ' -f1)"
done

check_csv() {
    local f actual
    for f in "${CSV_FILES[@]}"; do
        actual="$(sha256sum "$CSV_DIR/$f" | cut -d' ' -f1)"
        [[ "$actual" == "${CSV_HASH[$f]}" ]] || { echo "ERROR GRAVE: CSV cambiado durante la prueba: $f" >&2; return 1; }
    done
    echo '[OK] Los tres CSV siguen intactos (SHA256).'
}

pg_query() {
    docker compose exec -T postgres sh -c 'exec psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<< "$1"
}

hash_tabla() {
    local tabla="$1"
    case "$tabla" in
      cuentas_intereses|transacciones_procesadas|estados_cuenta_anuales|resumen_transacciones_diarias) : ;;
      *) echo "Tabla desconocida $tabla" >&2; return 1 ;;
    esac
    pg_query "SELECT count(*)::text || '|' || md5(COALESCE(string_agg(fila,E'\\n' ORDER BY fila),'')) FROM (SELECT (to_jsonb(t) - 'ultima_instancia_id')::text fila FROM public.$tabla t) x;"
}

error() { echo "[ERROR] $*" >&2; exit 1; }

printf '\n========== 1/6 PRECONDICIONES =========='; printf '\n'
docker compose config --quiet
[[ "$(docker compose exec -T postgres sh -c 'printf %s "$POSTGRES_DB"')" == bancoxyz ]] || error 'La base de datos objetivo no es bancoxyz.'
docker compose exec -T postgres sh -c 'pg_isready -q -U "$POSTGRES_USER" -d "$POSTGRES_DB"' || error 'PostgreSQL no disponible.'
[[ "$(pg_query "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('pagos_solicitudes','pagos_saldos','pagos_movimientos','batch_job_execution','cuentas_intereses','transacciones_procesadas','estados_cuenta_anuales','resumen_transacciones_diarias');")" == 8 ]] || error 'Faltan tablas necesarias. No se ejecutara nada.'
for required in 'Semana 9/scripts/verificar_pagos_tls_kafka_s9.sh' 'Semana 9/scripts/reparar_conexion_y_validar_batch_s9.sh'; do
    [[ -f "$required" ]] || error "Falta el verificador previamente instalado: $required"
done

echo '[OK] Una base objetivo, migracion Pagos y tablas Batch presentes.'

printf '\n========== 2/6 CORRECCION MINIMA HTTP 409 / ERROR DISPATCH =========='; printf '\n'
SECURITY='Semana 9/pagos-service/src/main/java/cl/duoc/bancoxyz/pagos/SecurityConfig.java'
[[ -f "$SECURITY" && ! -L "$SECURITY" ]] || error "No se encuentra SecurityConfig.java o es symlink: $SECURITY"
# Solo modifica la configuracion HTTP si coincide con el codigo auditado.
# El permiso aplica EXCLUSIVAMENTE a DispatcherType.ERROR (NO a peticiones normales /error).
PATCH_STATUS="$(python3 - "$SECURITY" <<'PY'
from pathlib import Path
import hashlib, os, sys, tempfile
p=Path(sys.argv[1]); b=p.read_bytes(); s=b.decode('utf-8')
expected_sha='e7332f2318c6b7b8fa2433a6306c640e0ad566b6248e877e8a1a82de7e87cf6f'
patched_marker='.dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()'
if patched_marker in s:
    assert s.count(patched_marker)==1, 'Permiso error duplicado: revisar manualmente'
    print('YA_APLICADO'); raise SystemExit(0)
if hashlib.sha256(b).hexdigest()!=expected_sha:
    raise SystemExit('ERROR: SecurityConfig.java local no coincide con la version de Pagos auditada. No se modifica.')
needle='import org.springframework.context.annotation.Bean;'
needle2='                .authorizeHttpRequests(a -> a\n'
if s.count(needle)!=1 or s.count(needle2)!=1:
    raise SystemExit('ERROR: estructura SecurityConfig no coincide; archivo intacto.')
s=s.replace(needle,'import jakarta.servlet.DispatcherType;\n'+needle,1)
s=s.replace(needle2,needle2+'                        .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()\n',1)
fd,temp=tempfile.mkstemp(dir=p.parent,prefix='.security_patch_',suffix='.tmp')
try:
    with os.fdopen(fd,'wb') as out: out.write(s.encode('utf-8'))
    os.chmod(temp,p.stat().st_mode & 0o777)
    os.replace(temp,p)
finally:
    if os.path.exists(temp): os.unlink(temp)
print('APLICADO')
PY
)" || error 'No se aplico el parche de seguridad; revisar mensaje previo.'
echo "[OK] SecurityConfig: $PATCH_STATUS. JWT y scopes se conservan."

printf '\n========== 3/6 COMPILACION, JUNIT Y DESPLIEGUE PAGOS =========='; printf '\n'
mvn -B -ntp -f 'Semana 9/pagos-service/pom.xml' test || error 'Fallo de Maven/JUnit de Pagos. No se ejecutan pagos ni Batch.'
# Reconstruir SIEMPRE para garantizar que la imagen incluya SecurityConfig,
# incluso si una ejecucion anterior instalo el parche pero fallo al desplegar.
docker compose up -d --no-deps --build pagos-service || error 'Reconstruccion de Pagos fallo.'
CID="$(docker compose ps -q pagos-service)"
[[ -n "$CID" ]] || error 'No hay contenedor pagos-service.'
SALUD=''
for _ in {1..35}; do
    SALUD="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CID" 2>/dev/null || true)"
    [[ "$SALUD" == healthy ]] && break
    [[ "$SALUD" == exited || "$SALUD" == dead ]] && break
    sleep 2
done
if [[ "$SALUD" != healthy ]]; then
    docker compose logs --no-color --tail=70 pagos-service || true
    error "Pagos no esta HEALTHY ($SALUD)"
fi
echo '[OK] pagos-service HEALTHY.'

printf '\n========== 4/6 PRUEBA HTTP JWT: CONFLICTO, CONCURRENCIA Y PERSISTENCIA =========='; printf '\n'
# 'tu-dominio.cl' era texto ilustrativo y no debe intentar resolverse como un dominio real.
if [[ "${PUBLIC_TLS_DOMAIN:-}" == 'tu-dominio.cl' ]]; then
    echo '[AVISO] PUBLIC_TLS_DOMAIN=tu-dominio.cl es un ejemplo. Se omite la verificacion publica estricta.'
    env -u PUBLIC_TLS_DOMAIN bash 'Semana 9/scripts/verificar_pagos_tls_kafka_s9.sh' --laboratorio \
        || error 'Fallo de verificacion funcional de Pagos; NO se reejecutaran los CSV.'
else
    bash 'Semana 9/scripts/verificar_pagos_tls_kafka_s9.sh' --laboratorio \
        || error 'Fallo de verificacion funcional de Pagos; NO se reejecutaran los CSV.'
fi
check_csv

printf '\n========== 5/6 CSV REALES: ULTIMA REEJECUCION BATCH =========='; printf '\n'
TABLAS=(cuentas_intereses transacciones_procesadas estados_cuenta_anuales resumen_transacciones_diarias)
declare -A ANTES
for t in "${TABLAS[@]}"; do
    ANTES[$t]="$(hash_tabla "$t")" || error "No se pudo leer la huella de $t"
    [[ "${ANTES[$t]}" =~ ^[0-9]+\|[a-f0-9]{32}$ ]] || error "Huella invalida para $t: ${ANTES[$t]}"
    echo "ANTES $t: ${ANTES[$t]}"
done
# Este script existente confirma COMPLETED en Spring Y nueva JobExecution en PostgreSQL.
# Efectua escrituras idempotentes de resultados derivados y metadatos Batch.
bash 'Semana 9/scripts/reparar_conexion_y_validar_batch_s9.sh' \
    || error 'Un Job Batch fallo. No se certifica la idempotencia.'
for t in "${TABLAS[@]}"; do
    DESPUES="$(hash_tabla "$t")" || error "No se pudo leer la huella posterior de $t"
    [[ "$DESPUES" == "${ANTES[$t]}" ]] || error "IDEMPOTENCIA NO VERIFICADA: $t cambio: ${ANTES[$t]} -> $DESPUES"
    echo "[OK] $t: registros y contenido de negocio sin cambios ($DESPUES)"
done
check_csv

printf '\n========== 6/6 DICTAMEN TECNICO =========='; printf '\n'
echo '[OK] Pagos: JWT, 409 por conflicto, una liquidacion para clave repetida/concurrente, persistencia tras reinicio.'
echo '[OK] Batch: los tres Jobs COMPLETED nuevamente y cuatro tablas sin cambio de negocio.'
echo '[OK] Origenes CSV: hashes SHA256 intactos.'
echo '[AVISO] TLS publico NO certificado sin dominio real y cadena valida; Kafka permanece PLAINTEXT/local (no multi-AZ).'
echo '[AVISO] No se probaron recuperacion ante caida del servidor PostgreSQL ni seguridad monetaria de produccion.'
if (( LIMPIAR )); then
    echo '== Limpieza final opcional: exclusivamente Maven target =='
    bash 'Semana 9/scripts/cierre_total_bancoxyz_s9.sh' --solo-limpiar-target || error 'Limpieza de target fallo.'
fi
echo 'RESULTADO TECNICO: 0'
