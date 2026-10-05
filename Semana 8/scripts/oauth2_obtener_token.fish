#!/usr/bin/env fish
# BancoXYZ - OAuth2 Client Credentials helper.
# Sin secretos hardcodeados. Lee variables exportadas o .env.
# Diseñado para Fish: sin indirecciones ni funciones dinámicas.

set -l SCRIPT_FILE (status --current-filename)
set -l SCRIPT_DIR (realpath (dirname "$SCRIPT_FILE"))

# Resolver raíz del repositorio de forma robusta.
set -l PROJECT_ROOT (git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)
if test -z "$PROJECT_ROOT"
    set PROJECT_ROOT (realpath "$SCRIPT_DIR/../..")
end

set -g ENV_FILE "$PROJECT_ROOT/.env"

if not test -f "$ENV_FILE"
    echo "No se encontró .env en $PROJECT_ROOT" >&2
    exit 10
end

# Lee UNA clave exacta desde .env sin imprimir otras variables.
function dotenv_get
    set -l NAME "$argv[1]"
    awk -F= -v key="$NAME" '
        $1 == key {
            sub(/^[^=]*=/, "")
            print
            exit
        }
    ' "$ENV_FILE"
end

# Cargar únicamente las variables que este helper necesita.
set -l ENV_WEB (dotenv_get OAUTH2_WEB_CLIENT_SECRET)
set -l ENV_MOBILE (dotenv_get OAUTH2_MOBILE_CLIENT_SECRET)
set -l ENV_ATM (dotenv_get OAUTH2_ATM_CLIENT_SECRET)
set -l ENV_PUBLIC_URL (dotenv_get KEYCLOAK_PUBLIC_URL)
set -l ENV_TOKEN_URL (dotenv_get OAUTH2_TOKEN_URL)

if test (count $argv) -lt 1
    echo "Uso: oauth2_obtener_token.fish web|mobile|atm" >&2
    exit 2
end

set -l PERFIL (string lower -- "$argv[1]")
set -l CLIENT_ID ""
set -l CLIENT_SECRET ""

switch "$PERFIL"
    case web
        set CLIENT_ID "bff-web-client"
        if set -q OAUTH2_WEB_CLIENT_SECRET
            set CLIENT_SECRET "$OAUTH2_WEB_CLIENT_SECRET"
        else
            set CLIENT_SECRET "$ENV_WEB"
        end
    case mobile
        set CLIENT_ID "bff-mobile-client"
        if set -q OAUTH2_MOBILE_CLIENT_SECRET
            set CLIENT_SECRET "$OAUTH2_MOBILE_CLIENT_SECRET"
        else
            set CLIENT_SECRET "$ENV_MOBILE"
        end
    case atm
        set CLIENT_ID "bff-atm-client"
        if set -q OAUTH2_ATM_CLIENT_SECRET
            set CLIENT_SECRET "$OAUTH2_ATM_CLIENT_SECRET"
        else
            set CLIENT_SECRET "$ENV_ATM"
        end
    case '*'
        echo "Perfil inválido: $PERFIL (use web, mobile o atm)" >&2
        exit 2
end

if test -z "$CLIENT_SECRET"; or test "$CLIENT_SECRET" = "CHANGE_ME"
    echo "Falta el client secret OAuth2 para $PERFIL en el entorno o en .env" >&2
    exit 3
end

set -l TOKEN_URL ""

if set -q OAUTH2_TOKEN_URL
    set TOKEN_URL "$OAUTH2_TOKEN_URL"
else if test -n "$ENV_TOKEN_URL"
    set TOKEN_URL "$ENV_TOKEN_URL"
else
    set -l PUBLIC_URL ""
    if set -q KEYCLOAK_PUBLIC_URL
        set PUBLIC_URL "$KEYCLOAK_PUBLIC_URL"
    else
        set PUBLIC_URL "$ENV_PUBLIC_URL"
    end

    if test -z "$PUBLIC_URL"
        set PUBLIC_URL "http://localhost:8084"
    end

    set PUBLIC_URL (string trim -r -c '/' -- "$PUBLIC_URL")
    set TOKEN_URL "$PUBLIC_URL/realms/bancoxyz/protocol/openid-connect/token"
end

set -l RESPONSE (curl -fsS \
    --connect-timeout 5 \
    --max-time 15 \
    -X POST "$TOKEN_URL" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=client_credentials' \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "client_secret=$CLIENT_SECRET" 2>/dev/null)

if test $status -ne 0; or test -z "$RESPONSE"
    echo "No se pudo obtener token OAuth2 para $PERFIL" >&2
    exit 4
end

set -l TOKEN (printf '%s' "$RESPONSE" | jq -r '.access_token // empty' 2>/dev/null)

if test -z "$TOKEN"
    echo "Keycloak no devolvió access_token para $PERFIL" >&2
    exit 5
end

# stdout contiene únicamente el token.
printf '%s\n' "$TOKEN"
