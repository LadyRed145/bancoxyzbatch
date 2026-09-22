#!/usr/bin/env fish

# BancoXYZ - Semana 6
# Verificación NO destructiva de Actuator + Resilience4j.
# Requiere activos: Config Server, Eureka, Bank Backend y los tres BFF.
#
# Comprueba:
# - Health público de los tres BFF.
# - Registro de Circuit Breaker, Retry y Rate Limiter como "bankbackend".
# - APIs principales respondiendo 200 con su token correcto.
# - Rate Limiter funcional mediante una ráfaga concurrente: debe haber 200 y 429.
# - El Circuit Breaker WEB permanece CLOSED y sin fallos tras los 429.
#
# La prueba destructiva de Retry/Circuit Breaker (backend DOWN) se realiza aparte
# para no detener servicios automáticamente durante una auditoría normal.

set WEB_TOKEN (set -q WEB_API_TOKEN; and echo $WEB_API_TOKEN; or echo 'bancoxyz-web-demo-token-2026')
set MOBILE_TOKEN (set -q MOBILE_API_TOKEN; and echo $MOBILE_API_TOKEN; or echo 'bancoxyz-mobile-demo-token-2026')
set ATM_TOKEN (set -q ATM_API_TOKEN; and echo $ATM_API_TOKEN; or echo 'bancoxyz-atm-demo-token-2026')

set FALLAS 0
set TMP_JSON /tmp/bancoxyz_actuator.json

function ok
    set_color green
    echo "✅ $argv"
    set_color normal
end

function fail
    set_color red
    echo "❌ $argv"
    set_color normal
    set -g FALLAS (math $FALLAS + 1)
end

function titulo
    echo
    set_color --bold cyan
    echo "===== $argv ====="
    set_color normal
end

function comprobar_health
    set nombre $argv[1]
    set url $argv[2]

    set codigo (curl -ksS -o $TMP_JSON -w '%{http_code}' "$url")

    if test "$codigo" = '200'; and jq -e '.status == "UP"' $TMP_JSON >/dev/null 2>&1
        ok "$nombre health -> HTTP 200 / UP"
    else
        fail "$nombre health -> HTTP $codigo"
        cat $TMP_JSON
    end
end

function comprobar_api
    set nombre $argv[1]
    set token $argv[2]
    set url $argv[3]

    set codigo (curl -ksS \
        -H "Authorization: Bearer $token" \
        -o /dev/null \
        -w '%{http_code}' \
        "$url")

    if test "$codigo" = '200'
        ok "$nombre -> HTTP 200"
    else
        fail "$nombre -> HTTP $codigo"
    end
end

function comprobar_circuitbreaker
    set nombre $argv[1]
    set token $argv[2]
    set url $argv[3]

    set codigo (curl -ksS \
        -H "Authorization: Bearer $token" \
        -o $TMP_JSON \
        -w '%{http_code}' \
        "$url")

    if test "$codigo" = '200'; and jq -e '.circuitBreakers.bankbackend' $TMP_JSON >/dev/null 2>&1
        set estado (jq -r '.circuitBreakers.bankbackend.state' $TMP_JSON)
        ok "$nombre -> bankbackend registrado / estado $estado"
    else
        fail "$nombre -> endpoint o instancia bankbackend no disponible (HTTP $codigo)"
        cat $TMP_JSON
    end
end

function comprobar_lista_resilience
    set nombre $argv[1]
    set token $argv[2]
    set url $argv[3]
    set campo $argv[4]

    set codigo (curl -ksS \
        -H "Authorization: Bearer $token" \
        -o $TMP_JSON \
        -w '%{http_code}' \
        "$url")

    if test "$codigo" = '200'; and jq -e --arg campo "$campo" '.[$campo] | index("bankbackend") != null' $TMP_JSON >/dev/null 2>&1
        ok "$nombre -> bankbackend registrado"
    else
        fail "$nombre -> bankbackend no encontrado (HTTP $codigo)"
        cat $TMP_JSON
    end
end

function probar_rate_limit
    set nombre $argv[1]
    set token $argv[2]
    set url $argv[3]

    # Dejamos que comience un nuevo período del Rate Limiter antes de la ráfaga.
    sleep 2

    set temporal (mktemp /tmp/bancoxyz_rate_XXXXXX)

    seq 1 30 | xargs -P30 -I{} \
        curl -ksS -o /dev/null \
        -w '%{http_code}\n' \
        -H "Authorization: Bearer $token" \
        "$url" > $temporal

    set permitidas (awk '$1 == "200" {c++} END {print c+0}' $temporal)
    set limitadas (awk '$1 == "429" {c++} END {print c+0}' $temporal)
    set otras (awk '$1 != "200" && $1 != "429" {c++} END {print c+0}' $temporal)

    echo "$nombre -> 200: $permitidas | 429: $limitadas | otros: $otras"

    if test $permitidas -gt 0; and test $limitadas -gt 0; and test $otras -eq 0
        ok "$nombre Rate Limiter funcional"
    else
        fail "$nombre Rate Limiter no mostró la combinación esperada 200 + 429"
        echo 'Códigos observados:'
        sort $temporal | uniq -c
    end

    rm -f $temporal
end

function comprobar_cb_web_sano
    curl -ksS \
        -H "Authorization: Bearer $WEB_TOKEN" \
        -o $TMP_JSON \
        'https://127.0.0.1:8081/actuator/circuitbreakers'

    set estado (jq -r '.circuitBreakers.bankbackend.state // "MISSING"' $TMP_JSON)
    set fallidas (jq -r '.circuitBreakers.bankbackend.failedCalls // -1' $TMP_JSON)

    echo "WEB Circuit Breaker después del Rate Limiter -> state=$estado | failedCalls=$fallidas"

    if test "$estado" = 'CLOSED'; and test "$fallidas" = '0'
        ok 'Los HTTP 429 no contaminan el Circuit Breaker'
    else
        fail 'El Circuit Breaker WEB no quedó sano después de la prueba de Rate Limiter'
    end
end

set_color --bold
printf '\nBANCOXYZ — AUDITORÍA ACTUATOR + RESILIENCE4J — SEMANA 6\n'
set_color normal
printf 'Modo: no destructivo\n'
printf 'Instancia Resilience4j esperada: bankbackend\n'

# 1) Health
titulo '1. ACTUATOR HEALTH'
comprobar_health 'WEB' 'https://127.0.0.1:8081/actuator/health'
comprobar_health 'MOBILE' 'https://127.0.0.1:8082/actuator/health'
comprobar_health 'ATM' 'https://127.0.0.1:8083/actuator/health'

# 2) Registro de patrones de resiliencia
titulo '2. CIRCUIT BREAKER REGISTRADO'
comprobar_circuitbreaker 'WEB' $WEB_TOKEN 'https://127.0.0.1:8081/actuator/circuitbreakers'
comprobar_circuitbreaker 'MOBILE' $MOBILE_TOKEN 'https://127.0.0.1:8082/actuator/circuitbreakers'
comprobar_circuitbreaker 'ATM' $ATM_TOKEN 'https://127.0.0.1:8083/actuator/circuitbreakers'

titulo '3. RETRY REGISTRADO'
comprobar_lista_resilience 'WEB Retry' $WEB_TOKEN 'https://127.0.0.1:8081/actuator/retries' 'retries'
comprobar_lista_resilience 'MOBILE Retry' $MOBILE_TOKEN 'https://127.0.0.1:8082/actuator/retries' 'retries'
comprobar_lista_resilience 'ATM Retry' $ATM_TOKEN 'https://127.0.0.1:8083/actuator/retries' 'retries'

titulo '4. RATE LIMITER REGISTRADO'
comprobar_lista_resilience 'WEB Rate Limiter' $WEB_TOKEN 'https://127.0.0.1:8081/actuator/ratelimiters' 'rateLimiters'
comprobar_lista_resilience 'MOBILE Rate Limiter' $MOBILE_TOKEN 'https://127.0.0.1:8082/actuator/ratelimiters' 'rateLimiters'
comprobar_lista_resilience 'ATM Rate Limiter' $ATM_TOKEN 'https://127.0.0.1:8083/actuator/ratelimiters' 'rateLimiters'

# 3) APIs sanas
titulo '5. APIS PRINCIPALES'
comprobar_api 'WEB /api/web/cuentas' $WEB_TOKEN 'https://127.0.0.1:8081/api/web/cuentas'
comprobar_api 'MOBILE /api/mobile/cuentas' $MOBILE_TOKEN 'https://127.0.0.1:8082/api/mobile/cuentas'
comprobar_api 'ATM /api/atm/cuentas/101/saldo' $ATM_TOKEN 'https://127.0.0.1:8083/api/atm/cuentas/101/saldo'

# 4) Rate Limiter real
titulo '6. RATE LIMITER — RAFAGA CONTROLADA'
probar_rate_limit 'WEB' $WEB_TOKEN 'https://127.0.0.1:8081/api/web/cuentas'
probar_rate_limit 'MOBILE' $MOBILE_TOKEN 'https://127.0.0.1:8082/api/mobile/cuentas'
probar_rate_limit 'ATM' $ATM_TOKEN 'https://127.0.0.1:8083/api/atm/cuentas/101/saldo'

# 5) Los 429 no deben contabilizarse como fallos del backend
titulo '7. AISLAMIENTO RATE LIMITER / CIRCUIT BREAKER'
comprobar_cb_web_sano

# Resumen
echo
set_color --bold
if test $FALLAS -eq 0
    set_color green
    echo '=============================================='
    echo 'RESULTADO: TODAS LAS PRUEBAS NO DESTRUCTIVAS PASARON'
    echo 'Actuator + Circuit Breaker + Retry + Rate Limiter: OK'
    echo '=============================================='
    set_color normal
    rm -f $TMP_JSON
    exit 0
else
    set_color red
    echo '=============================================='
    echo "RESULTADO: $FALLAS PRUEBA(S) FALLARON"
    echo 'Revisar la salida anterior antes de capturar evidencia.'
    echo '=============================================='
    set_color normal
    rm -f $TMP_JSON
    exit 1
end
