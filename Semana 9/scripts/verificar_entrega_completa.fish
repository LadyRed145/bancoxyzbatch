#!/usr/bin/env fish

# BancoXYZ Semana 9 - verificacion integral y reproducible.
# Ejecutar desde cualquier carpeta: fish "Semana 9/scripts/verificar_entrega_completa.fish"
# No elimina el volumen principal. Para Batch recrea exclusivamente la base
# aislada bancoxyz_batch_eft_aislado dentro del PostgreSQL del proyecto.

set -g ROOT (cd (dirname (status --current-filename))/../..; and pwd)
set -g SCRIPTS "$ROOT/Semana 9/scripts"
set -g BATCH "$ROOT/Semana 9/batch-service"
set -g FAILURES 0
set -g PASSES 0
set -g EC2_MODE 0
set -g COMPOSE docker compose

if contains -- --ec2 $argv
    set -g EC2_MODE 1
    set -g COMPOSE docker compose --profile ec2
end

function ok
    set -g PASSES (math $PASSES + 1)
    set_color green
    echo "OK  $argv"
    set_color normal
end

function fail
    set -g FAILURES (math $FAILURES + 1)
    set_color red
    echo "ERROR  $argv"
    set_color normal
end

function run_step --argument-names label
    echo
    set_color --bold cyan
    echo "===== $label ====="
    set_color normal
    $argv[2..-1]
    if test $status -eq 0
        ok "$label"
        return 0
    end
    fail "$label"
    return 1
end

function dotenv_get --argument-names name
    awk -F= -v key="$name" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$ROOT/.env"
end

function compose
    command $COMPOSE $argv
end

function wait_container --argument-names name
    for attempt in (seq 1 60)
        set state (docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$name" 2>/dev/null)
        if test "$state" = healthy; or test "$state" = running
            return 0
        end
        sleep 2
    end
    return 1
end

function verify_csv
    set data "$BATCH/src/main/resources/data"
    for file in estados_financieros_anuales.csv intereses_trimestrales.csv movimientos_financieros_diarios.csv
        set rows (math (wc -l < "$data/$file") - 1)
        if test "$rows" -ne 1000
            echo "$file contiene $rows registros; se esperaban 1000."
            return 1
        end
    end
end

function verify_database_snapshot
    set user (dotenv_get POSTGRES_USER)
    set database (dotenv_get POSTGRES_DB)
    test -n "$user"; or set user bancoxyz
    test -n "$database"; or set database bancoxyz
    docker exec bancoxyz-postgres psql -U "$user" -d "$database" -v ON_ERROR_STOP=1 -Atc \
        "SELECT CASE WHEN (SELECT count(*) FROM cuentas_intereses)=50 AND (SELECT count(*) FROM estados_cuenta_anuales)=20 AND (SELECT count(*) FROM transacciones_procesadas)=482 AND (SELECT count(*) FROM resumen_transacciones_diarias)=265 THEN 'OK' ELSE 'BAD' END" \
        | string match -q OK
end

function verify_keycloak_public_tls
    set domain (dotenv_get KEYCLOAK_DOMAIN)
    test -n "$domain"; or begin
        echo "Falta KEYCLOAK_DOMAIN en .env"
        return 1
    end

    curl --fail --silent --show-error \
        --connect-timeout 10 \
        --max-time 30 \
        "https://$domain/realms/bancoxyz/.well-known/openid-configuration" \
        | jq -e --arg issuer "https://$domain/realms/bancoxyz" '.issuer == $issuer' >/dev/null
end

function run_batch_jobs
    # BANCOXYZ_S9_VERIFICADOR_NO_DESTRUCTIVO_V2
    # Los jobs de integración requieren una base aislada preparada explícitamente.
    # No recrear, truncar ni modificar bases desde una verificación general.
    echo "BLOQUEADO: prueba Batch con efectos en BD; preparar y validar entorno por separado."
    return 1
end
cd "$ROOT"; or exit 1

for command in fish java docker curl jq awk openssl
    command -q "$command"; or fail "Falta dependencia: $command"
end

if not test -f "$ROOT/.env"
    fail "Falta .env. Copia .env.example a .env y reemplaza todos los CHANGE_ME."
else if grep -q 'CHANGE_ME' "$ROOT/.env"
    fail ".env todavia contiene valores CHANGE_ME."
else
    ok "Configuracion .env presente y sin placeholders"
end

test $FAILURES -eq 0; or exit 1

run_step "CSV oficiales: estructura y volumen" verify_csv
run_step "Compilacion y pruebas Maven" ./mvnw clean verify
run_step "Validacion Docker Compose" compose config --quiet
run_step "Auditoria Kafka sin duplicados" fish "$SCRIPTS/auditar_kafka_huerfanos.fish"

echo
echo "Construyendo y levantando el stack completo. La primera ejecucion puede tardar varios minutos."
run_step "Docker Compose build/up" compose up -d --build

for container in bancoxyz-postgres bancoxyz-keycloak bancoxyz-config-server bancoxyz-discovery-server bancoxyz-bank-backend bancoxyz-bff-web bancoxyz-bff-mobile bancoxyz-bff-atm
    run_step "Readiness $container" wait_container "$container"
end

if test $EC2_MODE -eq 1
    run_step "Readiness bancoxyz-caddy" wait_container bancoxyz-caddy
    run_step "Keycloak publico con TLS valido" verify_keycloak_public_tls
end

run_step "Snapshot procesado de los CSV" verify_database_snapshot
run_step "Ejecucion real de los tres Jobs Batch" run_batch_jobs
run_step "OAuth2: 200, 401 y 403" fish "$SCRIPTS/verificar_oauth2.fish"
run_step "Tres BFF: payload, HTTPS y seguridad" fish "$SCRIPTS/verificar_bff.fish"
run_step "Cluster Kafka" fish "$SCRIPTS/verificar_kafka_cluster.fish"
run_step "Productor y consumidor Kafka" fish "$SCRIPTS/verificar_kafka_microservicios.fish"
run_step "Pausa y reanudacion del listener" fish "$SCRIPTS/verificar_control_kafka_listener.fish"
run_step "Resilience4j: fallo y recuperacion" fish "$SCRIPTS/verificar_resilience4j_fallo_recuperacion.fish"
run_step "Retiro real controlado" fish "$SCRIPTS/verificar_retiro_controlado.fish"

echo
echo "======================================================"
echo "RESUMEN: $PASSES verificaciones correctas | $FAILURES fallidas"
if test $FAILURES -eq 0
    set_color --bold green
    echo "RESULTADO FINAL: ENTREGA VERIFICADA"
    set_color normal
    exit 0
end
set_color --bold red
echo "RESULTADO FINAL: REVISAR LOS BLOQUES MARCADOS COMO ERROR"
set_color normal
exit 1
