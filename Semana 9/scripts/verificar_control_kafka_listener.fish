#!/usr/bin/env fish
# BancoXYZ - Semana 9
# Evidencia: OAuth2, pausa/reanudacion del listener y lag real de Kafka.
# No modifica CSV legacy ni crea respaldos.
# IMPORTANTE: ejecuta un retiro controlado SOLO si confirma la pausa.

set -l ROOT (dirname (dirname (dirname (status --current-filename))))
cd "$ROOT"; or exit 1

set -l BASE_URL "http://localhost:8091/api/kafka/consumer"
set -l KAFKA "bancoxyz-kafka-1"
set -l GROUP "bancoxyz-retiros-group"
set -l TOPIC "bancoxyz.retiros"
set -l TMP_RETIRO (mktemp /tmp/bancoxyz_listener_retiro_XXXXXX)
or exit 1

set -g LISTENER_RECOVERY_REQUIRED 0
set -g LISTENER_RECOVERY_BASE_URL "$BASE_URL"
set -g LISTENER_RECOVERY_TOKEN ""

function api_get --argument-names base_url endpoint token
    curl -fsS --connect-timeout 5 --max-time 15 \
        -H "Authorization: Bearer $token" "$base_url/$endpoint"
end

function api_post --argument-names base_url endpoint token
    curl -fsS --connect-timeout 5 --max-time 15 -X POST \
        -H "Authorization: Bearer $token" "$base_url/$endpoint"
end

# Si la ejecucion termina antes de confirmar reanudacion, se intenta recuperar.
# SIGKILL, cortes de energia o caidas del host no ejecutan este manejador.
function recuperar_listener --on-event fish_exit
    if test "$LISTENER_RECOVERY_REQUIRED" = "1"
        if test -n "$LISTENER_RECOVERY_TOKEN"
            curl -fsS --connect-timeout 3 --max-time 8 -X POST \
                -H "Authorization: Bearer $LISTENER_RECOVERY_TOKEN" \
                "$LISTENER_RECOVERY_BASE_URL/reanudar" >/dev/null 2>&1
        end
    end
end

function finalizar --argument-names codigo
    rm -f "$TMP_RETIRO"
    exit "$codigo"
end

# Nunca transformar un error de Kafka, offsets ausentes o lag '-' en cero.
# Exigimos tres filas de particiones validas para este topic de 3 particiones.
function lag_total --argument-names kafka group topic
    set -l salida (docker exec "$kafka" \
        /opt/kafka/bin/kafka-consumer-groups.sh \
        --bootstrap-server localhost:19092 \
        --describe --group "$group" 2>/dev/null)
    set -l docker_status $status

    if test $docker_status -ne 0; or test (count $salida) -eq 0
        echo "ERROR"
        return 1
    end

    printf '%s\n' $salida | awk -v topic="$topic" '
        {
            for (i = 1; i <= NF; i++) {
                if ($i == topic) {
                    p = $(i + 1)
                    current = $(i + 2)
                    endoff = $(i + 3)
                    lag = $(i + 4)
                    if (p !~ /^[0-9]+$/) next
                    rows++
                    if (current == "-" && endoff == "0" && lag == "-") {
                        # Particion vacia, aun sin offset confirmado: lag real 0.
                    } else if (current !~ /^[0-9]+$/ ||
                               endoff !~ /^[0-9]+$/ ||
                               lag !~ /^[0-9]+$/) {
                        invalid = 1
                    } else {
                        total += lag
                    }
                    break
                }
            }
        }
        END {
            if (rows != 3 || invalid) {
                print "ERROR"
                exit 1
            }
            print total + 0
        }
    '
end

function obtener_estado --argument-names base token
    set -l respuesta (api_get "$base" estado "$token")
    or return 1
    printf '%s\n' $respuesta | jq -ce . 2>/dev/null
end

echo "=========================================================="
echo " BANCOXYZ - CONTROL SEGURO DE KAFKA LISTENER"
echo " VERSION FINAL 2026-10-11-C | JSON VALIDADO"
echo "=========================================================="

set -l TOKEN_WEB (fish "Semana 9/scripts/oauth2_obtener_token.fish" web)
set -l TOKEN_ATM (fish "Semana 9/scripts/oauth2_obtener_token.fish" atm)
set -g LISTENER_RECOVERY_TOKEN "$TOKEN_WEB"

if test -z "$TOKEN_WEB"; or test -z "$TOKEN_ATM"
    echo "❌ No fue posible obtener los tokens OAuth2 requeridos."
    finalizar 1
end

echo
echo "1. SPRING SECURITY / OAUTH2"
set -l NO_TOKEN (curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 15 "$BASE_URL/estado")
set -l WRONG_SCOPE (curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 15 \
    -H "Authorization: Bearer $TOKEN_ATM" "$BASE_URL/estado")
set -l WEB_OK (curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 15 \
    -H "Authorization: Bearer $TOKEN_WEB" "$BASE_URL/estado")

echo "   Sin token .............. HTTP $NO_TOKEN"
echo "   Scope ATM .............. HTTP $WRONG_SCOPE"
echo "   Scope WEB .............. HTTP $WEB_OK"

if test "$NO_TOKEN" != "401"; or test "$WRONG_SCOPE" != "403"; or test "$WEB_OK" != "200"
    echo "❌ Seguridad no confirmada. No se pausara el listener."
    finalizar 1
end

echo
echo "2. ESTADO INICIAL"
set -l ESTADO_INICIAL (obtener_estado "$BASE_URL" "$TOKEN_WEB")
if test $status -ne 0
    echo "❌ No se pudo consultar el estado inicial."
    finalizar 1
end
echo "$ESTADO_INICIAL" | jq .

# Validar directamente el JSON: evita conversiones booleanas ambiguas.
# jq -e devuelve 0 solo si AMBAS condiciones son verdaderas.
set -l ESTADO_INICIAL_VALIDO (printf '%s\n' $ESTADO_INICIAL | jq -r '(.estado == "ACTIVO") and (.ejecutando == true) and (.pausaSolicitada == false) and (.consumidorPausado == false)' 2>/dev/null)
if test "$ESTADO_INICIAL_VALIDO" != "true"
    echo "❌ Estado inicial no valido o JSON inesperado. No se modifica."
    echo "   Diagnostico: " (printf '%s\n' $ESTADO_INICIAL | jq -c '{estado, ejecutando, pausaSolicitada, consumidorPausado}' 2>/dev/null)
    finalizar 1
end

set -l LAG_INICIAL (lag_total "$KAFKA" "$GROUP" "$TOPIC")
if not string match -qr '^[0-9]+$' -- "$LAG_INICIAL"
    echo "❌ No se pudo medir el lag inicial. No se modifica el listener."
    finalizar 1
end
echo "   Lag inicial ............ $LAG_INICIAL"

echo
echo "3. PAUSAR LISTENER"
# Activar recuperacion ANTES del POST: una respuesta perdida puede haber pausado.
set -g LISTENER_RECOVERY_REQUIRED 1
set -l PAUSA_RESP (api_post "$BASE_URL" pausar "$TOKEN_WEB")
set -l PAUSA_STATUS $status
if test $PAUSA_STATUS -ne 0
    echo "❌ Fallo la solicitud de pausa. Se intentara reanudar al salir."
    finalizar 1
end
echo "$PAUSA_RESP" | jq . 2>/dev/null

set -l PAUSADO "false"
for intento in (seq 1 10)
    sleep 1
    set -l ESTADO_PAUSA (obtener_estado "$BASE_URL" "$TOKEN_WEB")
    if test $status -eq 0
        set PAUSADO (echo "$ESTADO_PAUSA" | jq -r 'if .consumidorPausado == null then false else .consumidorPausado end')
    end
    if test "$PAUSADO" = "true"
        break
    end
end

if test "$PAUSADO" != "true"
    echo "❌ Listener no confirmo pausa. No se realizara retiro."
    finalizar 1
end
echo "   Listener efectivamente pausado ✅"

echo
echo "4. GENERAR EVENTO MIENTRAS ESTA PAUSADO"
fish "Semana 9/scripts/verificar_retiro_controlado.fish" >"$TMP_RETIRO" 2>&1
set -l RETIRO_STATUS $status
if test $RETIRO_STATUS -eq 0
    grep -E 'Saldo antes:|^Retiro:|Saldo después:' "$TMP_RETIRO"
else
    echo "   Retiro controlado .......... FALLO ❌"
    sed 's/^/      /' "$TMP_RETIRO"
end

set -l LAG_PAUSADO "ERROR"
if test $RETIRO_STATUS -eq 0
    for intento in (seq 1 10)
        sleep 1
        set LAG_PAUSADO (lag_total "$KAFKA" "$GROUP" "$TOPIC")
        if string match -qr '^[0-9]+$' -- "$LAG_PAUSADO"
            if test "$LAG_PAUSADO" -gt "$LAG_INICIAL"
                break
            end
        end
    end
end
echo "   Lag con listener pausado .... $LAG_PAUSADO"

echo
echo "5. RESUMEN DEL CLUSTER / LISTENER"
set -l RESUMEN (api_get "$BASE_URL" resumen "$TOKEN_WEB")
set -l RESUMEN_STATUS $status
set -l RESUMEN_BROKERS 0
set -l RESUMEN_PARTICIONES 0
set -l RESUMEN_RF 0
if test $RESUMEN_STATUS -eq 0
    echo "$RESUMEN" | jq . 2>/dev/null
    set RESUMEN_BROKERS (echo "$RESUMEN" | jq -r '.brokers // 0' 2>/dev/null)
    set RESUMEN_PARTICIONES (echo "$RESUMEN" | jq -r '.particiones // 0' 2>/dev/null)
    set RESUMEN_RF (echo "$RESUMEN" | jq -r '.factorReplicacionMin // 0' 2>/dev/null)
else
    echo "   No se pudo consultar el resumen."
end

echo
echo "6. REANUDAR LISTENER"
set -l REANUDAR_RESP (api_post "$BASE_URL" reanudar "$TOKEN_WEB")
set -l REANUDAR_STATUS $status
if test $REANUDAR_STATUS -eq 0
    echo "$REANUDAR_RESP" | jq . 2>/dev/null
else
    echo "   Fallo la solicitud de reanudacion ❌"
end

set -l LAG_FINAL "ERROR"
set -l ESTADO_FINAL_NOMBRE "DESCONOCIDO"
set -l ESTADO_FINAL_PAUSADO "true"
for intento in (seq 1 15)
    sleep 1
    set LAG_FINAL (lag_total "$KAFKA" "$GROUP" "$TOPIC")
    set -l ESTADO_FINAL (obtener_estado "$BASE_URL" "$TOKEN_WEB")
    if test $status -eq 0
        set ESTADO_FINAL_NOMBRE (echo "$ESTADO_FINAL" | jq -r '.estado // "DESCONOCIDO"')
        set ESTADO_FINAL_PAUSADO (echo "$ESTADO_FINAL" | jq -r 'if .consumidorPausado == null then true else .consumidorPausado end')
    end
    if test "$LAG_FINAL" = "0"; and test "$ESTADO_FINAL_NOMBRE" = "ACTIVO"; and test "$ESTADO_FINAL_PAUSADO" = "false"
        set -g LISTENER_RECOVERY_REQUIRED 0
        break
    end
end

echo
echo "7. ESTADO FINAL"
echo "   Estado ................... $ESTADO_FINAL_NOMBRE"
echo "   Consumidor pausado ....... $ESTADO_FINAL_PAUSADO"
echo "   Lag final ................ $LAG_FINAL"

set -l PASS 1
if test $PAUSA_STATUS -ne 0; set PASS 0; end
if test "$PAUSADO" != "true"; set PASS 0; end
if test $RETIRO_STATUS -ne 0; set PASS 0; end
if not string match -qr '^[0-9]+$' -- "$LAG_PAUSADO"
    set PASS 0
else if test "$LAG_PAUSADO" -le "$LAG_INICIAL"
    set PASS 0
end
for valor in "$RESUMEN_BROKERS" "$RESUMEN_PARTICIONES" "$RESUMEN_RF"
    if not string match -qr '^[0-9]+$' -- "$valor"
        set PASS 0
    else if test "$valor" -lt 3
        set PASS 0
    end
end
if test $REANUDAR_STATUS -ne 0; set PASS 0; end
if test "$LAG_FINAL" != "0"; set PASS 0; end
if test "$ESTADO_FINAL_NOMBRE" != "ACTIVO"; set PASS 0; end
if test "$ESTADO_FINAL_PAUSADO" != "false"; set PASS 0; end

echo
echo "=========================================================="
if test $PASS -eq 1
    echo "✅ SPRING SECURITY + PAUSA/REANUDACION KAFKA FUNCIONALES"
    echo "   401/403/200 + pausa + aumento de lag + reanudacion + lag 0"
    echo "   Resumen: 3 brokers + 3 particiones + RF=3"
else
    echo "❌ REVISAR CONTROL / SEGURIDAD / LAG DEL LISTENER"
    if test "$LISTENER_RECOVERY_REQUIRED" = "1"
        echo "⚠ No se confirmo recuperacion completa; se intentara reanudar al salir."
    end
end
echo "=========================================================="

if test $PASS -eq 1
    finalizar 0
else
    finalizar 1
end
