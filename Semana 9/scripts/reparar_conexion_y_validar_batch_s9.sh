#!/usr/bin/env bash
# BancoXYZ S9: reintento controlado de los tres Jobs contra el PostgreSQL de Compose.
# No modifica fuentes CSV, no ejecuta DDL, DROP, TRUNCATE, Docker up/down ni backups.
# Es compatible con una terminal Fish: se invoca mediante bash.
set -Eeuo pipefail

fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '\n== %s ==\n' "$*"; }

[[ -f 'docker-compose.yml' && -d 'Semana 9/batch-service' ]] || fail 'Ejecuta el script desde la raiz de bancoxyzbatch.'
for comando in docker python3 mvn sha256sum; do
    command -v "$comando" >/dev/null 2>&1 || fail "No encuentro el comando requerido: $comando"
done

docker compose ps --status running --services | grep -qx 'postgres' || fail 'El servicio postgres de Docker Compose no esta en ejecucion.'
CONTAINER_ID="$(docker compose ps -q postgres)"
[[ -n "$CONTAINER_ID" ]] || fail 'No se pudo identificar el contenedor PostgreSQL.'

docker compose exec -T postgres sh -c 'pg_isready -q -U "$POSTGRES_USER" -d "$POSTGRES_DB"' || fail 'PostgreSQL no esta listo para conexiones.'

# Credenciales y nombre real obtenidos del contenedor existente, no de defaults inventados.
DB_NAME="$(docker compose exec -T postgres sh -c 'printf "%s" "$POSTGRES_DB"')"
DB_USER="$(docker compose exec -T postgres sh -c 'printf "%s" "$POSTGRES_USER"')"
DB_PASSWORD="$(docker compose exec -T postgres sh -c 'printf "%s" "$POSTGRES_PASSWORD"')"
[[ -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASSWORD" ]] || fail 'Falta nombre, usuario o password en el contenedor PostgreSQL.'
[[ "$DB_NAME" == 'bancoxyz' ]] || fail "La BD de Compose es '$DB_NAME', pero se esperaba 'bancoxyz'. No procesare datos en otra BD."

# Validar que los metadatos Spring Batch existen en la BD que se quiere usar.
query_sql() {
  docker compose exec -T postgres sh -c 'psql -X -At -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<< "$1"
}
[[ "$(query_sql "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('batch_job_instance','batch_job_execution','cuentas_intereses','transacciones_procesadas','estados_cuenta_anuales');")" == '5' ]] || fail 'No estan todas las tablas base y metadatos Batch en bancoxyz.'

# Descubrir una ruta TCP real desde el host. No suponer que POSTGRES_PORT de .env funciona.
CANDIDATES=()
PORT_LINE="$(docker compose port postgres 5432 2>/dev/null || true)"
if [[ -n "$PORT_LINE" ]]; then
    # Soporta 0.0.0.0:puerto, 127.0.0.1:puerto, [::]:puerto.
    HOST_PORT="${PORT_LINE##*:}"
    if [[ "$HOST_PORT" =~ ^[0-9]+$ ]]; then
      CANDIDATES+=("127.0.0.1:$HOST_PORT")
    fi
fi
# En Linux, Docker bridge generalmente es accesible directamente desde el host.
while IFS= read -r ip; do
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && CANDIDATES+=("$ip:5432")
done < <(docker inspect -f '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' "$CONTAINER_ID")

ENDPOINT=''
for candidate in "${CANDIDATES[@]}"; do
    if python3 - "$candidate" <<'PYSOCKET'
import socket,sys
host,port=sys.argv[1].rsplit(':',1)
try:
    with socket.create_connection((host,int(port)),timeout=2):
        pass
except OSError:
    sys.exit(1)
PYSOCKET
    then
        ENDPOINT="$candidate"
        break
    fi
done
[[ -n "$ENDPOINT" ]] || fail 'PostgreSQL funciona dentro de Docker, pero no tiene TCP accesible desde este host. Ejecuta: docker compose port postgres 5432 ; docker compose ps postgres. No cambies volumenes ni uses down -v.'

# No confiar en una URL antigua exportada en Fish o guardada en .env.
export BATCH_DB_URL="jdbc:postgresql://${ENDPOINT}/${DB_NAME}"
export BATCH_DB_USER="$DB_USER"
export BATCH_DB_PASSWORD="$DB_PASSWORD"
unset DB_URL || true
printf 'Conectando Spring Batch a: jdbc:postgresql://%s/%s (usuario: %s)\n' "$ENDPOINT" "$DB_NAME" "$DB_USER"

SOURCE_DIR='Semana 9/batch-service/src/main/resources/data'
CSVS=(movimientos_financieros_diarios.csv intereses_trimestrales.csv estados_financieros_anuales.csv)
HASHES=()
for csv in "${CSVS[@]}"; do
    [[ -s "$SOURCE_DIR/$csv" ]] || fail "CSV ausente o vacio: $csv"
    HASHES+=("$(sha256sum "$SOURCE_DIR/$csv" | cut -d' ' -f1)")
done

# Spring Boot Maven puede devolver 0 aunque el contexto falle. Para confirmar:
# 1) exigimos la traza de COMPLETED y
# 2) una nueva ejecucion COMPLETED persistida en BATCH_JOB_EXECUTION.
last_execution() {
    local job="$1"
    query_sql "SELECT COALESCE((SELECT e.job_execution_id::text || '|' || e.status FROM batch_job_execution e INNER JOIN batch_job_instance i ON i.job_instance_id=e.job_instance_id WHERE i.job_name='$job' ORDER BY e.job_execution_id DESC LIMIT 1), '0|NONE');"
}

info 'Ejecucion controlada de los tres Jobs Batch'
JOBS=(transaccionJob cuentaInteresJob estadoCuentaAnualJob)
step=0
for job in "${JOBS[@]}"; do
    step=$((step+1))
    antes="$(last_execution "$job")"
    antes_id="${antes%%|*}"
    [[ "$antes_id" =~ ^[0-9]+$ ]] || fail "No se puede interpretar metadato previo del Job $job: $antes"
    runid="$(date +%s%N)"
    printf '\n[%s/3] Ejecutando %s (anterior executionId=%s)\n' "$step" "$job" "$antes_id"
    # Capturar stdout+stderr sin crear archivos temporales de datos ni snapshots.
    if salida="$(mvn -B -q -f 'Semana 9/batch-service/pom.xml' spring-boot:run "-Dspring-boot.run.arguments=--app.batch.job=$job --app.batch.run-id=$runid" 2>&1)"; then
        :
    else
        printf '%s\n' "$salida" | tail -80 >&2
        fail "Maven reporto fallo en $job. No se ejecutaran los demas Jobs."
    fi
    if ! grep -qF '[BATCH] Estado final: COMPLETED' <<< "$salida"; then
        printf '%s\n' "$salida" | tail -80 >&2
        fail "Spring Batch NO confirmo COMPLETED para $job, aunque Maven devolvio 0."
    fi
    despues="$(last_execution "$job")"
    despues_id="${despues%%|*}"
    despues_estado="${despues#*|}"
    if [[ ! "$despues_id" =~ ^[0-9]+$ || "$despues_id" -le "$antes_id" || "$despues_estado" != 'COMPLETED' ]]; then
        printf '%s\n' "$salida" | tail -60 >&2
        fail "Job $job no registra una NUEVA ejecucion COMPLETED en PostgreSQL: antes=$antes despues=$despues"
    fi
    printf '%s\n' "$salida" | grep -E '\[BATCH\] (Ejecutando Job|JobExecution ID|Estado final)|\[BATCH-PERF\] job=' || true
    printf 'OK: %s persistido en BD (executionId=%s, estado=%s)\n' "$job" "$despues_id" "$despues_estado"
done

for index in 0 1 2; do
    hash_final="$(sha256sum "$SOURCE_DIR/${CSVS[$index]}" | cut -d' ' -f1)"
    [[ "$hash_final" == "${HASHES[$index]}" ]] || fail "CAMBIO DETECTADO en el CSV fuente ${CSVS[$index]}"
done

info 'Conteos de tablas derivadas (solo lectura)'
query_sql "SELECT 'cuentas_intereses=' || count(*) FROM cuentas_intereses UNION ALL SELECT 'transacciones_procesadas=' || count(*) FROM transacciones_procesadas UNION ALL SELECT 'estados_cuenta_anuales=' || count(*) FROM estados_cuenta_anuales;"
printf '\nOK REAL: 3 Jobs COMPLETED en PostgreSQL y 3 CSV intactos.\n'
printf 'No se modificaron configuraciones, volumenes, bases antiguas ni snapshots.\n'
