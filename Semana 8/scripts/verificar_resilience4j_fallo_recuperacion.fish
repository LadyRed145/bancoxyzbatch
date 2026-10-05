#!/usr/bin/env fish

set -g SCRIPT_FILE (status --current-filename)
set -g SCRIPT_DIR (realpath (dirname "$SCRIPT_FILE"))
set -g PROJECT_ROOT (git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)

if test -z "$PROJECT_ROOT"
    set -g PROJECT_ROOT (realpath "$SCRIPT_DIR/../..")
end
set -g TOKEN_SCRIPT "$PROJECT_ROOT/Semana 8/scripts/oauth2_obtener_token.fish"

set -g API_URL "https://127.0.0.1:8081/api/web/cuentas"
set -g CB_URL "https://127.0.0.1:8081/actuator/circuitbreakers"
set -g RETRY_URL "https://127.0.0.1:8081/actuator/retryevents"
set -g RETRIES_URL "https://127.0.0.1:8081/actuator/retries"
set -g RATELIMITERS_URL "https://127.0.0.1:8081/actuator/ratelimiters"

set -g BACKEND "bancoxyz-bank-backend"
set -g BFF "bancoxyz-bff-web"
set -g BACKEND_DETENIDO 0
set -g WEB_TOKEN ""

function cleanup_resilience_v5 --on-event fish_exit
    if test "$BACKEND_DETENIDO" = "1"
        docker start "$BACKEND" >/dev/null 2>&1
    end
end

function health_container
    docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $argv[1] 2>/dev/null
end

function cb_state
    curl -ksS \
        -H "Authorization: Bearer $WEB_TOKEN" \
        "$CB_URL" 2>/dev/null \
        | jq -r '.circuitBreakers.bankbackend.state // "UNKNOWN"'
end

function api_result
    set -l TMP (mktemp)
    set -l RESULT (curl -ksS \
        -H "Authorization: Bearer $WEB_TOKEN" \
        -o "$TMP" \
        -w '%{http_code}|%{time_total}' \
        "$API_URL" 2>/dev/null)
    rm -f "$TMP"
    echo "$RESULT"
end

function api_code
    set -l R (api_result)
    echo (string split "|" "$R")[1]
end

function esperar_health
    set -l CONTENEDOR $argv[1]
    set -l MAX $argv[2]

    for i in (seq 1 "$MAX")
        set -l H (health_container "$CONTENEDOR")
        if test "$H" = "healthy"
            echo "$H"
            return 0
        end
        sleep 1
    end

    health_container "$CONTENEDOR"
    return 1
end

function backend_visible_desde_bff
    docker exec "$BFF" \
        curl -sS -o /dev/null -w '%{http_code}' \
        http://bank-backend:8080/actuator/health 2>/dev/null
end

cd "$PROJECT_ROOT"; or exit 1

echo "=========================================================="
echo " BANCOXYZ - RESILIENCE4J / FALLO Y RECUPERACIÓN FINAL"
echo "=========================================================="

echo
echo "1. PREPARACIÓN"

# Reinicia sólo el BFF para comenzar con métricas/estado Resilience4j limpios.
docker restart "$BFF" >/dev/null
set -l BFF_HEALTH (esperar_health "$BFF" 40)

set -g WEB_TOKEN (fish "$TOKEN_SCRIPT" web)

if test -z "$WEB_TOKEN"
    echo "❌ No se pudo obtener token OAuth2 WEB."
    exit 1
end

set -l BACKEND_HEALTH (health_container "$BACKEND")
set -l CB_INICIAL (cb_state)

set -l RETRY_REG (curl -ksS \
    -H "Authorization: Bearer $WEB_TOKEN" \
    "$RETRIES_URL" 2>/dev/null | grep -q "bankbackend"; and echo true; or echo false)

set -l RATE_REG (curl -ksS \
    -H "Authorization: Bearer $WEB_TOKEN" \
    "$RATELIMITERS_URL" 2>/dev/null | grep -q "bankbackend"; and echo true; or echo false)

echo "   BFF Web ................. $BFF_HEALTH"
echo "   Bank Backend ............ $BACKEND_HEALTH"
echo "   Circuit Breaker ......... $CB_INICIAL"
echo "   Retry bankbackend ....... $RETRY_REG"
echo "   Rate Limiter ............ $RATE_REG"

echo
echo "2. OPERACIÓN NORMAL"

set -l NORMAL (api_code)
echo "   Solicitud inicial ....... HTTP $NORMAL"

echo
echo "3. CAÍDA CONTROLADA"

docker stop "$BACKEND" >/dev/null
set -g BACKEND_DETENIDO 1
sleep 2

set -l FALLOS 0
set -l CB_CAIDA (cb_state)

for intento in (seq 1 5)
    if test "$CB_CAIDA" = "OPEN"
        break
    end

    set -l R (api_result)
    set -l P (string split "|" "$R")
    set -l CODE "$P[1]"
    set -l TIME "$P[2]"

    set FALLOS (math "$FALLOS + 1")
    echo "   Fallo $FALLOS ................ HTTP $CODE | $TIME s"

    set CB_CAIDA (cb_state)
end

echo "   Circuit Breaker ........ $CB_CAIDA"

set -l RAPIDO (api_result)
set -l RP (string split "|" "$RAPIDO")
set -l RAPIDO_CODE "$RP[1]"
set -l RAPIDO_TIME "$RP[2]"

echo "   Rechazo con OPEN ....... HTTP $RAPIDO_CODE | $RAPIDO_TIME s"

set -l RETRY_EVENTOS (curl -ksS \
    -H "Authorization: Bearer $WEB_TOKEN" \
    "$RETRY_URL" 2>/dev/null \
    | jq '[.retryEvents[]? | select(.retryName=="bankbackend")] | length')

echo "   Eventos Retry .......... $RETRY_EVENTOS"

echo
echo "4. RESTAURACIÓN"

docker start "$BACKEND" >/dev/null
set -g BACKEND_DETENIDO 0

set -l BACKEND_RECUP (esperar_health "$BACKEND" 40)
echo "   Bank Backend ............ $BACKEND_RECUP"

set -l DIRECTO "000"
for i in (seq 1 20)
    set DIRECTO (backend_visible_desde_bff)
    if test "$DIRECTO" = "200"
        break
    end
    sleep 2
end

echo "   Backend visto desde BFF . HTTP $DIRECTO"

echo
echo "5. RECUPERACIÓN ADAPTATIVA"

# No asumimos que la primera ventana HALF_OPEN tenga que cerrar.
# Si una probe falla y el circuito vuelve a OPEN, esperamos la próxima ventana.
set -l ESTADO_ANTERIOR ""
set -l CB_FINAL (cb_state)
set -l PROBES 0
set -l PROBES_OK 0
set -l CICLOS_OPEN 0

for paso in (seq 1 60)
    set CB_FINAL (cb_state)

    if test "$CB_FINAL" != "$ESTADO_ANTERIOR"
        echo "   Estado .................. $CB_FINAL"
        set ESTADO_ANTERIOR "$CB_FINAL"
    end

    if test "$CB_FINAL" = "CLOSED"
        break
    end

    if test "$CB_FINAL" = "OPEN"
        set CICLOS_OPEN (math "$CICLOS_OPEN + 1")
        sleep 2
        continue
    end

    if test "$CB_FINAL" = "HALF_OPEN"
        # Pequeña estabilización adicional antes de cada probe permitida.
        sleep 2

        set -l PR (api_result)
        set -l PP (string split "|" "$PR")
        set -l PCODE "$PP[1]"
        set -l PTIME "$PP[2]"

        set PROBES (math "$PROBES + 1")

        if test "$PCODE" = "200"
            set PROBES_OK (math "$PROBES_OK + 1")
        end

        echo "   Probe $PROBES ................ HTTP $PCODE | $PTIME s"
        sleep 1
        continue
    end

    sleep 1
end

set CB_FINAL (cb_state)

echo "   Circuit Breaker final .. $CB_FINAL"
echo "   Probes exitosas ........ $PROBES_OK/$PROBES"

echo
echo "6. VALIDACIÓN"

set -l PASS 1

function check_line
    set -l LABEL $argv[1]
    set -l OK $argv[2]

    if test "$OK" = "1"
        printf "   %-31s ✅\n" "$LABEL"
    else
        printf "   %-31s ❌\n" "$LABEL"
        set -g PASS 0
    end
end

check_line "Retry configurado" (test "$RETRY_REG" = "true"; and echo 1; or echo 0)
check_line "Rate Limiter configurado" (test "$RATE_REG" = "true"; and echo 1; or echo 0)
check_line "Operación normal HTTP 200" (test "$NORMAL" = "200"; and echo 1; or echo 0)
check_line "Circuit Breaker abre" (test "$CB_CAIDA" = "OPEN"; and echo 1; or echo 0)
check_line "Fallo rápido con circuito OPEN" (test "$RAPIDO_CODE" = "503"; and echo 1; or echo 0)
check_line "Backend recuperado" (test "$BACKEND_RECUP" = "healthy" -a "$DIRECTO" = "200"; and echo 1; or echo 0)
check_line "Recuperación a CLOSED" (test "$CB_FINAL" = "CLOSED"; and echo 1; or echo 0)

echo
echo "=========================================================="

if test "$PASS" = "1"
    echo "✅ RESILIENCE4J FUNCIONAL: FALLO + RECUPERACIÓN OK"
    echo "   CLOSED -> OPEN -> HALF_OPEN -> CLOSED verificado"
else
    echo "⚠ REVISAR RESULTADOS ANTES DE GUARDAR EVIDENCIA"
end

echo "=========================================================="

functions -e check_line
functions -e health_container
functions -e cb_state
functions -e api_result
functions -e api_code
functions -e esperar_health
functions -e backend_visible_desde_bff
functions -e cleanup_resilience_v5
