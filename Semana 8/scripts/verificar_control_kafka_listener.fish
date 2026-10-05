#!/usr/bin/env fish

# BancoXYZ - Semana 8
# Evidencia integrada:
# Spring Security + OAuth2 + pausa/reanudación @KafkaListener + lag Kafka.
# Incluye recuperación defensiva para no dejar el listener pausado si la prueba se interrumpe.

set -l ROOT (dirname (dirname (dirname (status --current-filename))))
cd "$ROOT"; or exit 1

set -l BASE_URL "http://localhost:8091/api/kafka/consumer"
set -l TOKEN_WEB (fish "Semana 8/scripts/oauth2_obtener_token.fish" web)
set -l TOKEN_ATM (fish "Semana 8/scripts/oauth2_obtener_token.fish" atm)
set -l KAFKA "bancoxyz-kafka-1"
set -l GROUP "bancoxyz-retiros-group"
set -l TOPIC "bancoxyz.retiros"
set -l TMP_RETIRO (mktemp /tmp/bancoxyz_listener_retiro_XXXXXX)

# Estado global exclusivo de este proceso Fish para recuperación al salir.
set -g LISTENER_RECOVERY_REQUIRED 0
set -g LISTENER_RECOVERY_BASE_URL "$BASE_URL"
set -g LISTENER_RECOVERY_TOKEN "$TOKEN_WEB"

if test -z "$TOKEN_WEB"; or test -z "$TOKEN_ATM"
    echo "❌ No fue posible obtener los tokens OAuth2 requeridos."
    rm -f "$TMP_RETIRO"
    exit 1
end

function api_get --argument-names base_url endpoint token
    curl -fsS \
        --connect-timeout 5 \
        --max-time 15 \
        -H "Authorization: Bearer $token" \
        "$base_url/$endpoint"
end

function api_post --argument-names base_url endpoint token
    curl -fsS \
        --connect-timeout 5 \
        --max-time 15 \
        -X POST \
        -H "Authorization: Bearer $token" \
        "$base_url/$endpoint"
end

function recuperar_listener --on-event fish_exit
    if test "$LISTENER_RECOVERY_REQUIRED" = "1"; and test -n "$LISTENER_RECOVERY_TOKEN"
        curl -fsS \
            --connect-timeout 3 \
            --max-time 8 \
            -X POST \
            -H "Authorization: Bearer $LISTENER_RECOVERY_TOKEN" \
            "$LISTENER_RECOVERY_BASE_URL/reanudar" \
            >/dev/null 2>&1
    end
end

function lag_total --argument-names kafka group topic
    set -l RESULT (docker exec "$kafka" \
        /opt/kafka/bin/kafka-consumer-groups.sh \
        --bootstrap-server localhost:19092 \
        --describe \
        --group "$group" 2>/dev/null \
        | awk -v topic="$topic" '
            {
                topic_col = 0

                for (i = 1; i <= NF; i++) {
                    if ($i == topic) {
                        topic_col = i
                        break
                    }
                }

                if (topic_col > 0) {
                    partition = $(topic_col + 1)
                    lag_value = $(topic_col + 4)

                    if (partition ~ /^[0-9]+$/) {
                        rows++
                        if (lag_value == "-" || lag_value == "") lag_value = 0
                        if (lag_value ~ /^[0-9]+$/) lag += lag_value
                    }
                }
            }
            END {
                if (rows > 0) print lag
            }
        ')

    if test -n "$RESULT"
        echo "$RESULT"
    else
        echo 0
    end
end

echo "=========================================================="
echo " BANCOXYZ - CONTROL SEGURO DE KAFKA LISTENER"
echo "=========================================================="

echo
echo "1. SPRING SECURITY / OAUTH2"

set -l NO_TOKEN (curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 15 \
    "$BASE_URL/estado")

set -l WRONG_SCOPE (curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 15 \
    -H "Authorization: Bearer $TOKEN_ATM" \
    "$BASE_URL/estado")

set -l WEB_OK (curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 15 \
    -H "Authorization: Bearer $TOKEN_WEB" \
    "$BASE_URL/estado")

echo "   Sin token .............. HTTP $NO_TOKEN"
echo "   Scope ATM .............. HTTP $WRONG_SCOPE"
echo "   Scope WEB .............. HTTP $WEB_OK"

echo
echo "2. ESTADO INICIAL"
set -l ESTADO_INICIAL (api_get "$BASE_URL" estado "$TOKEN_WEB")
echo "$ESTADO_INICIAL" | jq .

echo
echo "3. PAUSAR LISTENER"
set -l PAUSA_RESP (api_post "$BASE_URL" pausar "$TOKEN_WEB")
set -l PAUSA_STATUS $status

if test $PAUSA_STATUS -eq 0
    set -g LISTENER_RECOVERY_REQUIRED 1
end

echo "$PAUSA_RESP" | jq .

set -l PAUSADO "false"
for intento in (seq 1 10)
    sleep 1
    set -l ESTADO_PAUSA (api_get "$BASE_URL" estado "$TOKEN_WEB")
    set PAUSADO (echo "$ESTADO_PAUSA" | jq -r '.consumidorPausado // false')

    if test "$PAUSADO" = "true"
        echo "   Listener efectivamente pausado ✅"
        break
    end
end

if test "$PAUSADO" != "true"
    echo "   Listener no confirmó pausa ❌"
end

echo
echo "4. GENERAR EVENTO MIENTRAS ESTA PAUSADO"
fish "Semana 8/scripts/verificar_retiro_controlado.fish" >"$TMP_RETIRO" 2>&1
set -l RETIRO_STATUS $status

if test $RETIRO_STATUS -eq 0
    grep -E 'Saldo antes:|^Retiro:|Saldo después:' "$TMP_RETIRO"
else
    echo "   Retiro controlado .......... FALLÓ ❌"
    sed 's/^/      /' "$TMP_RETIRO"
end

set -l LAG_PAUSADO 0
for intento in (seq 1 10)
    sleep 1
    set LAG_PAUSADO (lag_total "$KAFKA" "$GROUP" "$TOPIC")

    if string match -qr '^[0-9]+$' -- "$LAG_PAUSADO"; and test "$LAG_PAUSADO" -ge 1
        break
    end
end

echo "   Lag con listener pausado .... $LAG_PAUSADO"

echo
echo "5. RESUMEN DEL CLUSTER / LISTENER"
set -l RESUMEN (api_get "$BASE_URL" resumen "$TOKEN_WEB")
echo "$RESUMEN" | jq .

set -l RESUMEN_BROKERS (echo "$RESUMEN" | jq -r '.brokers // 0')
set -l RESUMEN_PARTICIONES (echo "$RESUMEN" | jq -r '.particiones // 0')
set -l RESUMEN_RF (echo "$RESUMEN" | jq -r '.factorReplicacionMin // 0')

echo
echo "6. REANUDAR LISTENER"
set -l REANUDAR_RESP (api_post "$BASE_URL" reanudar "$TOKEN_WEB")
echo "$REANUDAR_RESP" | jq .

set -l LAG_FINAL "$LAG_PAUSADO"
set -l ESTADO_FINAL ""

for intento in (seq 1 15)
    sleep 1
    set LAG_FINAL (lag_total "$KAFKA" "$GROUP" "$TOPIC")
    set ESTADO_FINAL (api_get "$BASE_URL" estado "$TOKEN_WEB")
    set -l ESTADO_NOMBRE (echo "$ESTADO_FINAL" | jq -r '.estado // "DESCONOCIDO"')

    if test "$LAG_FINAL" = "0"; and test "$ESTADO_NOMBRE" = "ACTIVO"
        set -g LISTENER_RECOVERY_REQUIRED 0
        break
    end
end

echo
echo "7. ESTADO FINAL"
echo "$ESTADO_FINAL" | jq .
echo "   Lag final .................... $LAG_FINAL"

set -l PASS 1
if test "$NO_TOKEN" != "401"; set PASS 0; end
if test "$WRONG_SCOPE" != "403"; set PASS 0; end
if test "$WEB_OK" != "200"; set PASS 0; end
if test $PAUSA_STATUS -ne 0; set PASS 0; end
if test "$PAUSADO" != "true"; set PASS 0; end
if test $RETIRO_STATUS -ne 0; set PASS 0; end
if not string match -qr '^[0-9]+$' -- "$LAG_PAUSADO"; set PASS 0; end
if test "$LAG_PAUSADO" -lt 1; set PASS 0; end
if test "$RESUMEN_BROKERS" -lt 3; set PASS 0; end
if test "$RESUMEN_PARTICIONES" -lt 3; set PASS 0; end
if test "$RESUMEN_RF" -lt 3; set PASS 0; end
if test "$LAG_FINAL" != "0"; set PASS 0; end

set -l ESTADO_FINAL_NOMBRE (echo "$ESTADO_FINAL" | jq -r '.estado // "DESCONOCIDO"')
if test "$ESTADO_FINAL_NOMBRE" != "ACTIVO"; set PASS 0; end

# Si por alguna razón no se confirmó estado ACTIVO, fish_exit intentará reanudarlo igualmente.
if test "$ESTADO_FINAL_NOMBRE" = "ACTIVO"
    set -g LISTENER_RECOVERY_REQUIRED 0
end

echo
echo "=========================================================="
if test $PASS -eq 1
    echo "✅ SPRING SECURITY + PAUSA/REANUDACION KAFKA FUNCIONALES"
    echo "   401/403/200 + listener pausado + lag > 0 + reanudacion + lag 0"
    echo "   Resumen: 3 brokers + 3 particiones + RF=3"
else
    echo "❌ REVISAR CONTROL / SEGURIDAD / LAG DEL LISTENER"
end
echo "=========================================================="

rm -f "$TMP_RETIRO"
functions -e api_get
functions -e api_post
functions -e lag_total

if test $PASS -eq 1
    exit 0
else
    exit 1
end
