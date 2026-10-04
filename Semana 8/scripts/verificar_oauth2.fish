#!/usr/bin/env fish

# BancoXYZ - Semana 8
# Evidencia funcional de OAuth2 con Keycloak + Spring Security Resource Server.
#
# Comprueba:
# - Keycloak disponible.
# - Client Credentials para WEB, MOBILE y ATM.
# - Access token correcto -> 200.
# - Sin token -> 401.
# - Token inválido -> 401.
# - Token válido de otro canal -> 403.

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

function obtener_token
    set canal $argv[1]
    set token (fish "$SCRIPT_DIR/oauth2_obtener_token.fish" "$canal")

    if test $status -ne 0; or test -z "$token"
        fail "No pude obtener token OAuth2 para $canal"
        return 1
    end

    printf '%s\n' "$token"
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

set discovery_code (curl -sS -o /dev/null -w '%{http_code}' \
    'http://localhost:8084/realms/bancoxyz/.well-known/openid-configuration')

if test "$discovery_code" = '200'
    ok 'Keycloak / realm bancoxyz disponible'
else
    fail "Keycloak no está disponible (HTTP $discovery_code)"
end

set WEB_TOKEN (obtener_token web)
set MOBILE_TOKEN (obtener_token mobile)
set ATM_TOKEN (obtener_token atm)

if test -n "$WEB_TOKEN"
    ok 'Client Credentials WEB -> access token obtenido'
end

if test -n "$MOBILE_TOKEN"
    ok 'Client Credentials MOBILE -> access token obtenido'
end

if test -n "$ATM_TOKEN"
    ok 'Client Credentials ATM -> access token obtenido'
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
