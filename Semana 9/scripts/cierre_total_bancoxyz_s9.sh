#!/usr/bin/env bash
# BancoXYZ EFT S9: auditoria integral + pruebas reales + limpieza opcional de target/.
# Compatible con terminal Fish al invocarlo mediante: bash este_archivo.sh --todo --limpiar-target
# NO ejecuta DROP/TRUNCATE/DELETE SQL, no elimina volumenes/bases ni edita CSV.
# --todo REEJECUTA los 3 Jobs Batch sobre la BD existente (escritura derivada controlada).
set -Eeuo pipefail
export LC_ALL=C.UTF-8

uso() {
  cat <<'TXT'
USO: bash cierre_total_bancoxyz_s9.sh [opciones]
  --todo                  Estructura + rúbrica + Maven + Docker/PG + 3 Jobs Batch.
  --estatico              Solo código, estructura, Compose y entregables. No inicia Jobs.
  --sin-batch             Con --todo, omite la reejecución de los Jobs.
  --limpiar-target        Al final, elimina SOLO target/ de módulos con pom.xml.
  --solo-limpiar-target   Limpia los target/ sin hacer la auditoría.
  --probar-bff            Además ejecuta verificar_bff.fish (requiere stack levantado).
  --ayuda                 Muestra estas opciones.
No hay ninguna opción que borre bases de datos, volúmenes, CSV o snapshots.
TXT
}
MODO=todo; LIMPIAR=0; BATCH=1; BFF=0
for arg in "$@"; do
  case "$arg" in
    --todo) MODO=todo ;;
    --estatico) MODO=estatico ;;
    --sin-batch) BATCH=0 ;;
    --limpiar-target) LIMPIAR=1 ;;
    --solo-limpiar-target) MODO=solo_limpiar ;;
    --probar-bff) BFF=1 ;;
    --ayuda|-h|--help) uso; exit 0 ;;
    *) echo "ERROR: opcion desconocida: $arg" >&2; uso; exit 2 ;;
  esac
done
if [[ -d './Semana 9' && -f './pom.xml' ]]; then
  RAIZ="$(pwd -P)"
else
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  RAIZ="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)" || exit 2
fi
[[ -f "$RAIZ/pom.xml" && -d "$RAIZ/Semana 9" ]] || { echo 'ERROR: ejecuta desde raiz bancoxyzbatch (debe existir pom.xml y Semana 9/).' >&2; exit 2; }
cd "$RAIZ"

OK=0; AVISOS=0; FALLOS=0; PENDIENTES=0
ok()      { printf '[OK] %s\n' "$*"; OK=$((OK+1)); }
aviso()   { printf '[AVISO] %s\n' "$*"; AVISOS=$((AVISOS+1)); }
fallo()   { printf '[FALTA] %s\n' "$*"; FALLOS=$((FALLOS+1)); }
pend()    { printf '[MANUAL] %s\n' "$*"; PENDIENTES=$((PENDIENTES+1)); }
seccion() { printf '\n========== %s ==========\n' "$*"; }
hay()     { command -v "$1" >/dev/null 2>&1; }

# Solo borra directorios target/ cuyo padre inmediato sea un modulo Maven.
# find NO sigue enlaces; rutas y padres comprobados. No crea respaldos.
limpiar_targets() {
  seccion 'LIMPIEZA IDÉMPOTENTE: SOLO Maven target/'
  local total=0 candidato padre
  while IFS= read -r -d '' candidato; do
    [[ ! -L "$candidato" ]] || continue
    padre="$(dirname -- "$candidato")"
    [[ -f "$padre/pom.xml" ]] || continue
    # No aceptar target externos o de carpetas extrañas.
    case "$candidato" in "$RAIZ"/target|"$RAIZ"/'Semana 9'/*/target|"$RAIZ"/'Semana 9'/bff/*/target) ;; *) continue ;; esac
    rm -rf -- "$candidato"
    printf '[LIMPIADO] %s\n' "${candidato#"$RAIZ"/}"
    total=$((total+1))
  done < <(find "$RAIZ" -type d \( -name .git -o -name node_modules -o -name .mvn \) -prune -o -type d -name target -prune -print0)
  ok "$total carpetas target/ eliminadas; no se tocaron CSV, ZIP, codigo o BD."
}

if [[ "$MODO" == solo_limpiar ]]; then
  limpiar_targets
  exit 0
fi

seccion '1/7 FUENTES, ESTRUCTURA Y RÚBRICA'
CSV_DIR='Semana 9/batch-service/src/main/resources/data'
CSV=(movimientos_financieros_diarios.csv intereses_trimestrales.csv estados_financieros_anuales.csv)
declare -A CSV_HASH=()
for archivo in "${CSV[@]}"; do
  ruta="$CSV_DIR/$archivo"
  if [[ -s "$ruta" ]]; then
    if hay sha256sum; then
      CSV_HASH["$archivo"]="$(sha256sum -- "$ruta" | cut -d' ' -f1)"
    fi
    ok "CSV oficial presente: $archivo"
  else
    fallo "CSV ausente/vacio: $ruta"
  fi
done
if hay python3; then
  if python3 - "$CSV_DIR" <<'PYCSV'
from pathlib import Path
import csv,sys
root=Path(sys.argv[1])
expected={'movimientos_financieros_diarios.csv','intereses_trimestrales.csv','estados_financieros_anuales.csv'}
found={p.name for p in root.glob('*.csv')}
if found != expected:
    print('Inventario incorrecto, faltantes=',sorted(expected-found),'adicionales=',sorted(found-expected))
    sys.exit(1)
for name in sorted(expected):
    with (root/name).open(encoding='utf-8-sig',newline='') as f:
        reader=csv.reader(f)
        headers=next(reader,None)
        if not headers or not all(h.strip() for h in headers):
            print('Sin cabeceras completas:',name);sys.exit(1)
        qty=sum(1 for _ in reader)
        print('  CSV:',name,'filas=',qty)
        if qty==0:sys.exit(1)
PYCSV
  then ok 'Solo los 3 CSV esperados en resources/data, con encabezados y filas.'
  else fallo 'Inventario/lectura CSV inválidos.'; fi
else fallo 'Falta Python3 para verificar integridad estructural de CSV.'; fi

modulos=(shared-contracts shared-resilience batch-service bank-backend bff/bff-web bff/bff-mobile bff/bff-atm cuentas-service clientes-service pagos-service config-server discovery-server retiros-event-consumer)
for modulo in "${modulos[@]}"; do
  [[ -f "Semana 9/$modulo/pom.xml" ]] || fallo "No existe Maven POM: Semana 9/$modulo/pom.xml"
done
if [[ -f pom.xml ]] && ! grep -q 'Semana 8/' pom.xml && grep -q 'Semana 9/' pom.xml; then
  ok 'Reactor Maven de raiz apunta a Semana 9.'
else
  fallo 'Reactor Maven de raiz no está claramente alineado con Semana 9.'
fi
for pieza in 'Semana 9/bank-backend/src/main/java/cl/duoc/bancoxyz/backend/entity/RetiroIdempotencia.java' \
             'Semana 9/bank-backend/src/main/java/cl/duoc/bancoxyz/backend/repository/RetiroIdempotenciaRepository.java' \
             'Semana 9/data/db/03_retiros_idempotencia.sql'; do
  [[ -s "$pieza" ]] || fallo "Falta protección de idempotencia: $pieza"
done
props='Semana 9/batch-service/src/main/resources/application.properties'
if [[ -f "$props" ]] && grep -Eq '^spring\.datasource\.url=.*bancoxyz' "$props" && ! grep -Eq '^spring\.datasource\.url=.*bancoxyz_batch_eft_aislado' "$props"; then
  ok 'Batch configura por defecto bancoxyz (no la BD aislada).'
else
  fallo 'Batch puede seguir apuntando a BD aislada/otra BD.'
fi
if [[ -f 'Semana 9/scripts/verificar_entrega_completa.fish' ]]; then
  if grep -Eq 'DROP[[:space:]]+DATABASE|pg_terminate_backend' 'Semana 9/scripts/verificar_entrega_completa.fish'; then
    fallo 'verificar_entrega_completa.fish todavía tiene comandos de borrado de BD: NO ejecutarlo.'
  else
    ok 'Verificador integral sin DROP DATABASE/pg_terminate_backend.'
  fi
fi
if [[ -f 'Semana 9/bank-backend/src/main/java/cl/duoc/bancoxyz/backend/service/CuentaInteresService.java' ]] &&
   grep -q 'Idempotency\|RetiroIdempotencia\|recibos' 'Semana 9/bank-backend/src/main/java/cl/duoc/bancoxyz/backend/service/CuentaInteresService.java'; then
  ok 'Retiro con lógica de recibo de idempotencia presente (pendiente prueba de concurrencia real).'
else fallo 'Lógica idempotente de retiros ausente.'; fi
if grep -Rql 'afterCommit' 'Semana 9/bank-backend/src/main/java/cl/duoc/bancoxyz/backend/service'; then
  ok 'Publicación Kafka diferida al afterCommit implementada.'
else aviso 'No se detectó afterCommit en el servicio de retiro: verificar evento tras commit.'; fi
if [[ -f 'Semana 9/pagos-service/src/main/java/cl/duoc/bancoxyz/pagos/PagosController.java' ]]; then
  if grep -q 'NO modifica saldos' 'Semana 9/pagos-service/src/main/java/cl/duoc/bancoxyz/pagos/PagosController.java' ||
     grep -Eq "CHECK[[:space:]]*\([[:space:]]*estado[[:space:]]*=[[:space:]]*'PENDIENTE'" 'Semana 9/pagos-service/src/main/resources/schema.sql'; then
    fallo 'RÚBRICA #5: pagos-service solo registra PENDIENTE; no implementa liquidación de pagos/transferencias/depósitos.'
  else
    aviso 'Procesamiento monetario de pagos debe validarse funcionalmente (no basta con que compile).'
  fi
else fallo 'RÚBRICA #5: pagos-service no encontrado.'; fi

seccion '2/7 DOCKER COMPOSE, DEPENDENCIAS Y SEGURIDAD'
COMPOSE_OK=0
if hay docker && docker compose version >/dev/null 2>&1; then
  if docker compose config --quiet >/dev/null 2>&1; then
    COMPOSE_OK=1
    ok 'docker compose config validado (sin levantar/detener contenedores).'
    if docker compose config --format json >/dev/null 2>&1 && hay python3; then
      if docker compose config --format json | python3 -c '
import json,sys
x=json.load(sys.stdin); s=x.get("services",{})
for key in ("postgres","cuentas-service","clientes-service","pagos-service","bank-backend","bff-web","bff-mobile","bff-atm","config-server","discovery-server","keycloak"):
    if key not in s: print("FALTA_SERVICIO:",key);sys.exit(1)
pg=[k for k in s if k=="postgres" or k.startswith("postgres-")]
if len(pg)!=1:print("POSTGRES_REPLICAS:",pg);sys.exit(1)
for k in ("cuentas-service","clientes-service","pagos-service"):
    env=s[k].get("environment",{})
    if isinstance(env,list): env=dict(z.split("=",1) for z in env if "=" in z)
    jdbc=[str(v) for n,v in env.items() if ("DATASOURCE_URL" in n or "DB_URL" in n)]
    if not any("postgres:5432/" in v for v in jdbc):
        print("DB_URL_NO_UNIFICADA:",k);sys.exit(1)
print("OK: postgres unico y 3 servicios con URLs a postgres:5432 (instancia comun).")
' ; then ok 'Compose contiene 3 servicios bancarios y un solo servicio PostgreSQL compartido.'
      else fallo 'Compose no mantiene una sola instancia de PostgreSQL/unificación de microservicios.'; fi
    else aviso 'No pude comprobar semánticamente el Compose (formato JSON no disponible).'; fi
  else fallo 'docker compose config falla; revisar .env / rutas / variables.'; fi
else aviso 'Docker Compose no está disponible: validación runtime pendiente.'; fi
if [[ -f docker-compose.yml ]] && grep -Eq '02_seed_processed_snapshot\.sql:/docker-entrypoint-initdb.d/' docker-compose.yml; then
  fallo 'Compose aún monta snapshot SQL legacy como initdb: riesgo de datos obsoletos.'
else ok 'Compose no monta el snapshot de seed antiguo como initdb.'; fi
if [[ -f 'Semana 9/database/02_seed_processed_snapshot.sql' ]]; then
  aviso 'El snapshot SQL histórico sigue en Semana 9/database/: retirarlo solo tras validar la consolidación final.'
fi
if [[ -f docker-compose.yml ]] && grep -q 'Semana 8/' docker-compose.yml; then
  fallo 'docker-compose.yml tiene rutas a Semana 8.'
else ok 'Compose sin rutas antiguas a Semana 8.'; fi
for pieza in 'Semana 9/bff/bff-web' 'Semana 9/bff/bff-mobile' 'Semana 9/bff/bff-atm' \
             'Semana 9/cuentas-service' 'Semana 9/clientes-service' 'Semana 9/pagos-service'; do
  if [[ -d "$pieza" ]] && find "$pieza/src/main" -name '*.java' -print -quit 2>/dev/null | grep -q .; then
    ok "Código presente: ${pieza#Semana 9/}"
  else fallo "Falta código: $pieza"; fi
done

seccion '3/7 DOCUMENTACIÓN, VIDEO Y COHERENCIA'
for pieza in README.md instrucciones.md despliegue.md Propuesta_Tecnica.md; do
  [[ -s "$pieza" ]] && ok "Documento presente: $pieza" || fallo "Documento faltante: $pieza"
done
if [[ ! -f readme.md && -f README.md ]]; then
  aviso 'La pauta solicita readme.md en minúsculas; el proyecto tiene README.md. Confirmar formato/nombre requerido en entrega.'
fi
if [[ -f README.md ]] && grep -Eq 'https://github\.com/[^/ ]+/[^/ ]+' README.md; then
  ok 'README incluye enlace a repositorio GitHub.'
else
  fallo 'README no incluye enlace verificable a GitHub.'
fi
if grep -Eiq 'bancoxyz_batch_eft_aislado|PostgreSQL Batch aislado|BDB\["PostgreSQL Batch aislado"\]|batch en una base aislada' README.md instrucciones.md despliegue.md 2>/dev/null; then
  fallo 'DOCUMENTOS DESACTUALIZADOS: README/instrucciones/despliegue todavía hablan de Batch aislado.'
else ok 'Documentación no conserva referencias detectadas a la base Batch aislada.'; fi
if grep -Eiq 'validación del snapshot procesado|Snapshot: 50|snapshot incluido|datos del snapshot' README.md instrucciones.md despliegue.md 2>/dev/null; then
  aviso 'Documentación menciona snapshot legacy: actualizar a resultados reales de CSV Semana 9.'
fi
INFORME=''
while IFS= read -r -d '' pdf; do
  case "$pdf" in */historico/*|*/target/*|*/.git/*) continue ;; esac
  INFORME="$pdf";break
done < <(find "$RAIZ" -type d \( -name .git -o -name target \) -prune -o -type f -iname '*.pdf' -print0)
if [[ -n "$INFORME" ]]; then
  ok "PDF técnico localizado (revisar contenido y plantilla AVA): ${INFORME#"$RAIZ"/}"
  [[ "$(dirname -- "$INFORME")" == "$RAIZ" ]] || aviso 'El PDF no está junto a README/instrucciones/despliegue en raíz; la pauta solicita una carpeta de entrega común.'
else fallo 'ENTREGABLE #7: falta PDF técnico final de Semana 9 (no cuenta PDF histórico S8).'; fi
VIDEO=''
while IFS= read -r -d '' mp4; do
  VIDEO="$mp4"; break
done < <(find "$RAIZ" -type d \( -name .git -o -name target \) -prune -o -type f -iname '*.mp4' -print0)
if [[ -n "$VIDEO" ]]; then
  [[ "$(dirname -- "$VIDEO")" == "$RAIZ" ]] || aviso 'El MP4 no está en raíz junto a documentos; la pauta solicita una carpeta de entrega común.'
  if hay ffprobe; then
    dur="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -- "$VIDEO" 2>/dev/null || true)"
    if [[ "$dur" =~ ^[0-9]+([.][0-9]+)?$ ]] && python3 - "$dur" <<'PYDURATION'
import sys
v=float(sys.argv[1]);sys.exit(0 if 300<=v<=420 else 1)
PYDURATION
    then ok 'Video MP4 encontrado y duración 5-7 minutos.'
    else fallo 'Video MP4 con duración fuera de 5-7 min o archivo ilegible.'; fi
  else aviso 'MP4 localizado; duración no comprobable (ffprobe ausente).'; fi
  pend 'Revisar personalmente presencia de webcam y los 4 temas de la pauta en el video.'
else
  fallo 'ENTREGABLE #8: falta MP4 final de 5-7 min con webcam y 4 temas.'
fi
pend 'Evidencia de AWS EC2/TLS/escala horizontal y PDF contra plantilla AVA requieren validación externa/visual.'
pend 'Los criterios 1 y 2 requieren comprobar explicación de 5 procesos y 3 requisitos de negocio en propuesta final.'

PG_LISTO=0; DB_NOMBRE=''; DB_USER=''; DB_PASSWORD=''; ENDPOINT=''
pg_query() { docker compose exec -T postgres sh -c 'psql -X -At -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<< "$1"; }
seccion '4/7 POSTGRESQL: VALIDACIONES SOLO LECTURA'
if (( COMPOSE_OK )) && docker compose ps --status running --services 2>/dev/null | grep -qx postgres; then
  if docker compose exec -T postgres sh -c 'pg_isready -q -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
    DB_NOMBRE="$(docker compose exec -T postgres sh -c 'printf "%s" "$POSTGRES_DB"')"
    DB_USER="$(docker compose exec -T postgres sh -c 'printf "%s" "$POSTGRES_USER"')"
    DB_PASSWORD="$(docker compose exec -T postgres sh -c 'printf "%s" "$POSTGRES_PASSWORD"')"
    if [[ "$DB_NOMBRE" == bancoxyz && -n "$DB_USER" && -n "$DB_PASSWORD" ]]; then
      PG_LISTO=1; ok 'PostgreSQL activo; base objetivo = bancoxyz; credenciales recuperadas sin imprimir secretos.'
      TABLAS=(cuentas_intereses transacciones_procesadas estados_cuenta_anuales resumen_transacciones_diarias batch_job_instance batch_job_execution retiros_idempotencia cuentas_gestion clientes_perfil pagos_solicitudes)
      for tabla in "${TABLAS[@]}"; do
        salida="$(pg_query "SELECT to_regclass('public.$tabla') IS NOT NULL;" 2>/dev/null || true)"
        [[ "$salida" == t ]] && ok "Tabla presente: $tabla" || fallo "Falta tabla: $tabla"
      done
      pg_query "SELECT 'TABLA ' || name || ' = ' || cantidad FROM (SELECT 'cuentas_intereses' AS name, count(*) cantidad FROM cuentas_intereses UNION ALL SELECT 'transacciones_procesadas',count(*) FROM transacciones_procesadas UNION ALL SELECT 'estados_cuenta_anuales',count(*) FROM estados_cuenta_anuales UNION ALL SELECT 'resumen_transacciones_diarias',count(*) FROM resumen_transacciones_diarias) q;" 2>/dev/null || aviso 'No pude leer todos los conteos de las 4 tablas derivadas.'
      adicionales="$(pg_query "SELECT datname FROM pg_database WHERE datistemplate=false AND datname NOT IN ('postgres','bancoxyz') ORDER BY datname;" 2>/dev/null || true)"
      if [[ -n "$adicionales" ]]; then
        aviso 'Hay bases de datos adicionales: revisar su contenido antes de eliminar manualmente. El auditor NO ejecuta DROP DATABASE.'
        printf '%s\n' "$adicionales" | sed 's/^/  BD: /'
      else ok 'No se detectaron bases de usuario adicionales (excluyendo postgres).'; fi
    else fallo "PostgreSQL no apunta exclusivamente a bancoxyz (BD configurada: $DB_NOMBRE)."; fi
  else fallo 'Contenedor PostgreSQL ejecutándose pero pg_isready falla.'; fi
else fallo 'PostgreSQL de Compose no está activo: comprobaciones de integridad y Jobs pendientes.'; fi

# Huellas deterministas de datos de negocio; ignora metadata efímera de JobInstance.
# No usa pg_dump, tablas temporales, snapshots ni SQL de alteración.
huella_tabla() {
  local tabla="$1"
  pg_query "SELECT count(*)::text || '|' || md5(COALESCE(string_agg(fila, E'\\n' ORDER BY fila),'')) FROM (SELECT (to_jsonb(t) - 'ultima_instancia_id')::text AS fila FROM public.$tabla t) q;"
}

seccion '5/7 MAVEN: COMPILACIÓN Y TESTS AUTOMATIZADOS'
MAVEN_OK=0
if [[ "$MODO" == estatico ]]; then
  aviso 'Modo --estatico: Maven/JUnit no ejecutados.'
elif hay mvn; then
  printf 'Ejecutando reactor Maven con tests. No ejecuta Docker up/down.\n'
  LOG_MVN="$(mktemp /tmp/bancoxyz_mvn_XXXXXXXX)"
  if mvn -B -ntp -f pom.xml test >"$LOG_MVN" 2>&1; then
    MAVEN_OK=1
    ok 'Reactor Maven completo: BUILD SUCCESS.'
    grep -E 'Tests run:|BUILD SUCCESS' "$LOG_MVN" | tail -24 || true
  else
    fallo 'Reactor Maven/JUnit falló; últimas líneas:'
    tail -65 "$LOG_MVN" || true
  fi
  rm -f -- "$LOG_MVN"
else fallo 'Maven no está disponible; no pude ejecutar JUnit.'; fi

seccion '6/7 SPRING BATCH: REEJECUCIÓN, SQL PERSISTIDO E IDEMPOTENCIA'
if [[ "$MODO" == estatico || "$BATCH" -eq 0 ]]; then
  aviso 'Reejecución Batch omitida por opción del usuario; idempotencia no comprobada en esta ejecución.'
elif (( ! PG_LISTO || ! MAVEN_OK )); then
  fallo 'Batch NO ejecutado: PostgreSQL o Maven no aprobaron las precondiciones.'
else
  cid="$(docker compose ps -q postgres)"
  CANDIDATOS=()
  puerto="$(docker compose port postgres 5432 2>/dev/null || true)"
  port_num="${puerto##*:}"
  [[ "$port_num" =~ ^[0-9]+$ ]] && CANDIDATOS+=("127.0.0.1:$port_num")
  while IFS= read -r ip; do
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && CANDIDATOS+=("$ip:5432")
  done < <(docker inspect -f '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' "$cid" 2>/dev/null || true)
  for candidato in "${CANDIDATOS[@]}"; do
    if python3 - "$candidato" <<'PYSOCKET'
import socket,sys
host,port=sys.argv[1].rsplit(':',1)
try:
    with socket.create_connection((host,int(port)),timeout=2): pass
except OSError: sys.exit(1)
PYSOCKET
    then ENDPOINT="$candidato";break; fi
  done
  if [[ -z "$ENDPOINT" ]]; then
    fallo 'No hay endpoint TCP accesible para PostgreSQL desde host. No se alteró ningún Job.'
  else
    ok "Conexión host->PostgreSQL detectada en $ENDPOINT."
    huellas_antes=(); huellas_despues=(); TABLAS_DERIVADAS=(cuentas_intereses transacciones_procesadas estados_cuenta_anuales resumen_transacciones_diarias)
    HUELLAS_OK=1
    for tabla in "${TABLAS_DERIVADAS[@]}"; do
      valor="$(huella_tabla "$tabla" 2>/dev/null || true)"
      if [[ ! "$valor" =~ ^[0-9]+\|[a-f0-9]{32}$ ]]; then
        fallo "No se pudo leer la huella del estado previo en $tabla."; HUELLAS_OK=0
      fi
      huellas_antes+=("$valor")
    done
    if (( HUELLAS_OK )); then
      export BATCH_DB_URL="jdbc:postgresql://$ENDPOINT/$DB_NOMBRE"
      export BATCH_DB_USER="$DB_USER"
      export BATCH_DB_PASSWORD="$DB_PASSWORD"
      unset DB_URL || true
      jobs=(transaccionJob cuentaInteresJob estadoCuentaAnualJob)
      JOBS_OK=1
      index=0
      for job in "${jobs[@]}"; do
        index=$((index+1))
        previo="$(pg_query "SELECT coalesce(max(e.job_execution_id),0) FROM batch_job_execution e JOIN batch_job_instance i ON i.job_instance_id=e.job_instance_id WHERE i.job_name='$job';" 2>/dev/null || true)"
        if [[ ! "$previo" =~ ^[0-9]+$ ]]; then fallo "No se pudo obtener la ejecución previa de $job.";JOBS_OK=0;break;fi
        printf '\n[%d/3] %s: anterior=%s\n' "$index" "$job" "$previo"
        runid="$(date +%s%N)"
        LOG_JOB="$(mktemp /tmp/bancoxyz_job_XXXXXXXX)"
        if mvn -B -ntp -q -f 'Semana 9/batch-service/pom.xml' spring-boot:run "-Dspring-boot.run.arguments=--app.batch.job=$job --app.batch.run-id=$runid" >"$LOG_JOB" 2>&1 && grep -qF '[BATCH] Estado final: COMPLETED' "$LOG_JOB"; then
          ultimo="$(pg_query "SELECT coalesce((SELECT e.job_execution_id::text || '|' || e.status FROM batch_job_execution e JOIN batch_job_instance i ON i.job_instance_id=e.job_instance_id WHERE i.job_name='$job' ORDER BY e.job_execution_id DESC LIMIT 1),'0|NONE');" 2>/dev/null || true)"
          IFS='|' read -r nuevo estado <<< "$ultimo"
          if [[ "$nuevo" =~ ^[0-9]+$ && "$nuevo" -gt "$previo" && "$estado" == COMPLETED ]]; then
            ok "$job: executionId=$nuevo, COMPLETED confirmado en PostgreSQL."
            grep -E '\[BATCH-PERF\] job=' "$LOG_JOB" | tail -1 || true
          else
            fallo "$job: Maven informó éxito, PERO no hay nueva ejecución COMPLETED en PostgreSQL (último=$ultimo)."
            JOBS_OK=0
          fi
        else
          fallo "$job: Spring Batch no reportó COMPLETED."
          tail -55 "$LOG_JOB" || true
          JOBS_OK=0
        fi
        rm -f -- "$LOG_JOB"
        (( JOBS_OK )) || break
      done
      if (( JOBS_OK )); then
        for ix in "${!TABLAS_DERIVADAS[@]}"; do
          tabla="${TABLAS_DERIVADAS[$ix]}"
          despues="$(huella_tabla "$tabla" 2>/dev/null || true)"
          huellas_despues+=("$despues")
          if [[ "${huellas_antes[$ix]}" == "$despues" ]]; then
            ok "IDEMPOTENCIA: $tabla conserva conteo y contenido de negocio tras reejecución."
          else
            fallo "IDEMPOTENCIA: $tabla CAMBIÓ tras reejecutar Batch: antes=${huellas_antes[$ix]} despues=$despues"
          fi
        done
      else aviso 'No se compararon huellas finales: Jobs incompletos o fallidos.'; fi
    fi
  fi
fi

seccion '7/7 PROBES OPCIONALES Y CSV INTACTOS'
if (( BFF )); then
  if hay fish && [[ -f 'Semana 9/scripts/verificar_bff.fish' ]]; then
    if fish 'Semana 9/scripts/verificar_bff.fish'; then ok 'BFF: contratos/seguridad/HTTPS pasaron el script funcional.'
    else fallo 'BFF: script de pruebas funcionales reportó fallos.'; fi
  else fallo 'No están Fish o verificar_bff.fish disponibles.'; fi
else
  pend 'BFF/OAuth2/Kafka end-to-end: revisar evidencias previas o ejecutar con --probar-bff; no repetir pruebas destructivas del listener.'
fi
if hay sha256sum; then
  for archivo in "${CSV[@]}"; do
    if [[ -n "${CSV_HASH[$archivo]:-}" ]]; then
      final="$(sha256sum -- "$CSV_DIR/$archivo" | cut -d' ' -f1)"
      [[ "$final" == "${CSV_HASH[$archivo]}" ]] && ok "SHA256 CSV intacto: $archivo" || fallo "SE MODIFICÓ CSV: $archivo"
    fi
  done
fi

# El directorio targets solo se borra expresamente, NUNCA bases o SQL legacy.
if (( LIMPIAR )); then limpiar_targets; fi
seccion 'DICTAMEN FINAL (RÚBRICA EFT S9, NO PUNTAJE INVENTADO)'
printf '[RESUMEN] OK=%d | FALTAS=%d | AVISOS=%d | EVIDENCIAS MANUALES=%d\n' "$OK" "$FALLOS" "$AVISOS" "$PENDIENTES"
printf 'RÚBRICA: 1) procesos 2) arquitectura 3) 3 Batch 4) 3 BFF 5) 3 microservicios + Kafka 6) Docker/nube 7) 4 entregables 8) video MP4\n'
printf 'NO se han borrado bases antiguas, snapshots, volumenes ni CSV.\n'
if (( FALLOS > 0 )); then
  printf '\nCIERRE NO APROBADO: quedan %d punto(s) concretos que corregir/verificar. Codigo de salida 1.\n' "$FALLOS"
  exit 1
fi
if (( AVISOS > 0 || PENDIENTES > 0 )); then
  printf '\nCIERRE TÉCNICO SIN FALLOS AUTOMÁTICOS, PERO FALTAN verificaciones manuales/avisos. Codigo de salida 3.\n'
  exit 3
fi
printf '\nCIERRE AUTOMÁTICO APROBADO; revisar siempre entrega y video personalmente. Codigo de salida 0.\n'
exit 0
