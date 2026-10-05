#!/usr/bin/env fish

# BancoXYZ - Semana 8
# Evidencia funcional de OAuth2 con Keycloak + Spring Security Resource Server.
# Incluye readiness acotado para evitar falsos negativos durante el arranque.

set SCRIPT_DIR (cd (dirname (status --current-filename)); and pwd)
set -g FALLAS 0

for comando in curl jq
    if not command -q $comando
        echo "ERROR: falta el comando requerido: $comando"
        exit 1
    end
end

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

function esperar_http_200 --argument-names nombre url insecure
    set -l codigo 000

    for intento in (seq 1 20)
        if test "$insecure" = "1"
            set codigo (curl -ksS -o /dev/null -w '%{http_code}' \
                --connect-timeout 3 --max-time 8 "$url" 2>/dev/null)
        else
            set codigo (curl -sS -o /dev/null -w '%{http_code}' \
                --connect-timeout 3 --max-time 8 "$url" 2>/dev/null)
        end

        if test "$codigo" = "200"
            return 0
        end

        sleep 2
    end

    fail "$nombre no quedó listo (último HTTP $codigo)"
    return 1
end

function comprobar
    set titulo $argv[1]
    set esperado $argv[2]
    set token $argv[3]
    set url $argv[4]

    if test "$token" = '-'
        set codigo (curl -ksS -o /dev/null -w '%{http_code}' "$url")
    else
        set codigo (curl -ksS \
            -H "Authorization: Bearer $token" \
            -o /dev/null \
            -w '%{http_code}' \
            "$url")
    end

    echo "$titulo -> HTTP $codigo (esperado $esperado)"

    if test "$codigo" = "$esperado"
        ok "$titulo"
    else
        fail "$titulo"
    end
end

echo
set_color --bold cyan
echo '===== BANCOXYZ — OAUTH2 / KEYCLOAK — SEMANA 8 ====='
set_color normal

if esperar_http_200 'Keycloak / realm bancoxyz' \
        'http://localhost:8084/realms/bancoxyz/.well-known/openid-configuration' 0
    ok 'Keycloak / realm bancoxyz disponible'
end

# Esperamos que los BFF hayan terminado de arrancar antes de usarlos como evidencia.
if esperar_http_200 'BFF WEB health' 'https://localhost:8081/actuator/health' 1
    ok 'BFF WEB disponible'
end
if esperar_http_200 'BFF MOBILE health' 'https://localhost:8082/actuator/health' 1
    ok 'BFF MOBILE disponible'
end
if esperar_http_200 'BFF ATM health' 'https://localhost:8083/actuator/health' 1
    ok 'BFF ATM disponible'
end

set WEB_TOKEN (fish "$SCRIPT_DIR/oauth2_obtener_token.fish" web)
set WEB_STATUS $status
if test $WEB_STATUS -eq 0; and test -n "$WEB_TOKEN"
    ok 'Client Credentials WEB -> access token obtenido'
else
    set WEB_TOKEN 'token-web-no-disponible'
    fail 'No pude obtener token OAuth2 para web'
end

set MOBILE_TOKEN (fish "$SCRIPT_DIR/oauth2_obtener_token.fish" mobile)
set MOBILE_STATUS $status
if test $MOBILE_STATUS -eq 0; and test -n "$MOBILE_TOKEN"
    ok 'Client Credentials MOBILE -> access token obtenido'
else
    set MOBILE_TOKEN 'token-mobile-no-disponible'
    fail 'No pude obtener token OAuth2 para mobile'
end

set ATM_TOKEN (fish "$SCRIPT_DIR/oauth2_obtener_token.fish" atm)
set ATM_STATUS $status
if test $ATM_STATUS -eq 0; and test -n "$ATM_TOKEN"
    ok 'Client Credentials ATM -> access token obtenido'
else
    set ATM_TOKEN 'token-atm-no-disponible'
    fail 'No pude obtener token OAuth2 para atm'
end

echo
echo '--- Autenticación válida ---'
comprobar 'WEB con token WEB' 200 "$WEB_TOKEN" 'https://localhost:8081/api/web/cuentas'
comprobar 'MOBILE con token MOBILE' 200 "$MOBILE_TOKEN" 'https://localhost:8082/api/mobile/cuentas'
comprobar 'ATM con token ATM' 200 "$ATM_TOKEN" 'https://localhost:8083/api/atm/cuentas/101/saldo'

echo
echo '--- 401: autenticación ausente o inválida ---'
comprobar 'WEB sin token' 401 - 'https://localhost:8081/api/web/cuentas'
comprobar 'WEB con token inválido' 401 'jwt-invalido-para-prueba' 'https://localhost:8081/api/web/cuentas'

echo
echo '--- 403: token OAuth2 válido pero scope incorrecto ---'
comprobar 'WEB token intentando MOBILE' 403 "$WEB_TOKEN" 'https://localhost:8082/api/mobile/cuentas'
comprobar 'MOBILE token intentando ATM' 403 "$MOBILE_TOKEN" 'https://localhost:8083/api/atm/cuentas/101/saldo'
comprobar 'ATM token intentando WEB' 403 "$ATM_TOKEN" 'https://localhost:8081/api/web/cuentas'

echo
if test $FALLAS -eq 0
    set_color --bold green
    echo '======================================================'
    echo 'RESULTADO: OAUTH2 FUNCIONAL — TODAS LAS PRUEBAS PASARON'
    echo '200 autorizado | 401 no autenticado | 403 sin scope'
    echo '======================================================'
    set_color normal
    exit 0
else
    set_color --bold red
    echo '======================================================'
    echo "RESULTADO: $FALLAS PRUEBA(S) OAUTH2 FALLARON"
    echo '======================================================'
    set_color normal
    exit 1
end
