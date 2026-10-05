#!/usr/bin/env fish

# Crea una cuenta temporal a partir de la 101, ejecuta un retiro real de $1
# mediante el BFF ATM y elimina el fixture al terminar. Incluye reintentos
# acotados para absorber únicamente la ventana de arranque/registro Eureka.

set SCRIPT_DIR (cd (dirname (status --current-filename)); and pwd)
set ATM_TOKEN (fish "$SCRIPT_DIR/oauth2_obtener_token.fish" atm)
if test $status -ne 0; or test -z "$ATM_TOKEN"
    echo 'ERROR: no pude obtener token OAuth2 para atm.'
    exit 1
end

set DB_CONTAINER (set -q DB_CONTAINER; and echo $DB_CONTAINER; or echo 'bancoxyz-postgres')
set DB_USER (set -q DB_USER; and echo $DB_USER; or echo 'bancoxyz')
set DB_NAME (set -q DB_NAME; and echo $DB_NAME; or echo 'bancoxyz')

set SOURCE_ID 101
set TEST_ID 990101
set MONTO 1.00

function limpiar_cuenta_temporal
    docker exec -i $DB_CONTAINER \
        psql -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1 \
        -c "DELETE FROM cuentas_intereses WHERE cuenta_id = $TEST_ID;" \
        >/dev/null 2>&1
end

function cleanup --on-event fish_exit
    limpiar_cuenta_temporal
end

for comando in docker curl jq
    if not command -q $comando
        echo "ERROR: falta el comando requerido: $comando"
        exit 1
    end
end

if not docker ps --format '{{.Names}}' | string match -q -- $DB_CONTAINER
    echo "ERROR: el contenedor $DB_CONTAINER no está ejecutándose."
    exit 1
end

limpiar_cuenta_temporal

set sql "INSERT INTO cuentas_intereses \
(cuenta_id, activo, estado, interes_calculado, nombre, observacion, \
saldo_final, saldo_inicial, tasa_interes, tipo, ultima_instancia_id) \
SELECT $TEST_ID, activo, estado, interes_calculado, \
nombre || ' [PRUEBA ATM]', observacion, saldo_final, saldo_inicial, \
tasa_interes, tipo, ultima_instancia_id \
FROM cuentas_intereses \
WHERE cuenta_id = $SOURCE_ID;"

echo '=== Preparando cuenta temporal para la evidencia de retiro ==='

if not docker exec -i $DB_CONTAINER \
        psql -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1 \
        -c "$sql" >/dev/null

    echo 'ERROR: no pude crear la cuenta temporal.'
    exit 1
end

set antes_file /tmp/atm_saldo_antes.json
set antes_code 000

for intento in (seq 1 15)
    set antes_code (curl -ksS \
        -H "Authorization: Bearer $ATM_TOKEN" \
        -o $antes_file \
        -w '%{http_code}' \
        https://localhost:8083/api/atm/cuentas/$TEST_ID/saldo)

    if test "$antes_code" = '200'
        break
    end

    # Sólo reintento estados transitorios de disponibilidad/resiliencia.
    if string match -qr '^(429|502|503|504)$' -- "$antes_code"
        sleep 2
    else
        break
    end
end

if test "$antes_code" != '200'
    echo "ERROR: la consulta inicial devolvió HTTP $antes_code."
    cat $antes_file
    exit 1
end

set saldo_antes (jq -r '.saldoDisponible' $antes_file)
echo "Saldo antes: $saldo_antes"

set retiro_file /tmp/atm_retiro_controlado.json
set retiro_metricas (curl -ksS \
    -H "Authorization: Bearer $ATM_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"monto\":$MONTO}" \
    -o $retiro_file \
    -w '%{http_code}|%{size_download}|%{time_total}' \
    https://localhost:8083/api/atm/cuentas/$TEST_ID/retiro)

set partes (string split '|' $retiro_metricas)
set retiro_code $partes[1]

echo "Retiro: HTTP $retiro_code | bytes $partes[2] | tiempo $partes[3]s"
jq . $retiro_file

if test "$retiro_code" != '200'
    echo 'ERROR: el retiro controlado no fue exitoso.'
    exit 1
end

set despues_file /tmp/atm_saldo_despues.json
set despues_code 000

for intento in (seq 1 10)
    set despues_code (curl -ksS \
        -H "Authorization: Bearer $ATM_TOKEN" \
        -o $despues_file \
        -w '%{http_code}' \
        https://localhost:8083/api/atm/cuentas/$TEST_ID/saldo)

    if test "$despues_code" = '200'
        break
    end

    if string match -qr '^(429|502|503|504)$' -- "$despues_code"
        sleep 1
    else
        break
    end
end

if test "$despues_code" != '200'
    echo "ERROR: la consulta posterior devolvió HTTP $despues_code."
    cat $despues_file
    exit 1
end

set saldo_despues (jq -r '.saldoDisponible' $despues_file)
set diferencia (math --scale=2 "$saldo_antes - $saldo_despues")
set diferencia_formateada (printf '%.2f' $diferencia)
set monto_formateado (printf '%.2f' $MONTO)

echo "Saldo después: $saldo_despues"
echo "Diferencia observada: $diferencia_formateada"

if test "$diferencia_formateada" != "$monto_formateado"
    echo "ERROR: esperaba una diferencia de $monto_formateado."
    exit 1
end

limpiar_cuenta_temporal

set cleanup_code (curl -ksS \
    -H "Authorization: Bearer $ATM_TOKEN" \
    -o /dev/null \
    -w '%{http_code}' \
    https://localhost:8083/api/atm/cuentas/$TEST_ID/saldo)

echo "Limpieza de cuenta temporal: HTTP $cleanup_code (esperado 404)"

if test "$cleanup_code" != '404'
    echo 'ADVERTENCIA: revisa manualmente la limpieza del fixture temporal.'
    exit 1
end

echo '========================================'
echo 'VERIFICACIÓN DE RETIRO: OK'
echo 'Retiro real validado sin alterar la cuenta original.'
