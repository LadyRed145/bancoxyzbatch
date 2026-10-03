#!/usr/bin/env fish

# Esta prueba crea una cuenta temporal a partir de la 101, ejecuta un retiro real de $1
# a través del BFF ATM y elimina la cuenta temporal al terminar.
# De esta forma puedo demostrar una operación crítica real sin alterar los datos originales.

set ATM_TOKEN (set -q ATM_API_TOKEN; and echo $ATM_API_TOKEN; or echo 'bancoxyz-atm-demo-token-2026')
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

# Aunque la prueba falle a mitad de camino, intento eliminar siempre
# la cuenta temporal para no dejar residuos en la base de datos.
function cleanup --on-event fish_exit
    limpiar_cuenta_temporal
end

# Verifico las herramientas que necesito antes de modificar la base.
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

# Elimino un fixture previo por seguridad, en caso de que alguna ejecución
# anterior se haya interrumpido de forma inesperada.
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

# Consulto el saldo inicial utilizando exclusivamente el BFF ATM.
set antes_file /tmp/atm_saldo_antes.json

set antes_code (curl -ksS \
    -H "Authorization: Bearer $ATM_TOKEN" \
    -o $antes_file \
    -w '%{http_code}' \
    https://localhost:8083/api/atm/cuentas/$TEST_ID/saldo)

if test "$antes_code" != '200'
    echo "ERROR: la consulta inicial devolvió HTTP $antes_code."
    cat $antes_file
    exit 1
end

set saldo_antes (jq -r '.saldoDisponible' $antes_file)

echo "Saldo antes: $saldo_antes"

# Ejecuto un retiro real de $1 sobre la cuenta temporal.
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

# Consulto nuevamente el saldo para demostrar que la operación
# realmente fue persistida por el Bank Backend.
set despues_file /tmp/atm_saldo_despues.json

set despues_code (curl -ksS \
    -H "Authorization: Bearer $ATM_TOKEN" \
    -o $despues_file \
    -w '%{http_code}' \
    https://localhost:8083/api/atm/cuentas/$TEST_ID/saldo)

if test "$despues_code" != '200'
    echo "ERROR: la consulta posterior devolvió HTTP $despues_code."
    exit 1
end

set saldo_despues (jq -r '.saldoDisponible' $despues_file)
set diferencia (math --scale=2 "$saldo_antes - $saldo_despues")

# Fish puede representar matemáticamente 1.00 simplemente como 1.
# Para comparar importes monetarios sin depender de esa representación,
# normalizo ambos valores explícitamente a dos decimales.
set diferencia_formateada (printf '%.2f' $diferencia)
set monto_formateado (printf '%.2f' $MONTO)

echo "Saldo después: $saldo_despues"
echo "Diferencia observada: $diferencia_formateada"

if test "$diferencia_formateada" != "$monto_formateado"
    echo "ERROR: esperaba una diferencia de $monto_formateado."
    exit 1
end

# Elimino explícitamente la cuenta temporal una vez terminada la prueba.
limpiar_cuenta_temporal

# Finalmente verifico mediante el propio BFF que la cuenta temporal
# ya no se encuentre disponible.
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