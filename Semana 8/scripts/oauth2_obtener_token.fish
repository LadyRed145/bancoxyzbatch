#!/usr/bin/env fish

# BancoXYZ - OAuth2
# Obtiene un access token JWT desde Keycloak usando Client Credentials.
#
# Uso:
#   fish oauth2_obtener_token.fish web
#   fish oauth2_obtener_token.fish mobile
#   fish oauth2_obtener_token.fish atm
#
# El token se imprime únicamente por stdout para que otros scripts
# puedan capturarlo sin exponerlo en mensajes adicionales.

for comando in curl jq
    if not command -q $comando
        echo "ERROR: falta el comando requerido: $comando" >&2
        exit 1
    end
end

if test (count $argv) -ne 1
    echo 'ERROR: indica un canal: web, mobile o atm.' >&2
    exit 1
end

set canal (string lower -- $argv[1])
set token_url (set -q OAUTH2_TOKEN_URL; and echo $OAUTH2_TOKEN_URL; or echo 'http://localhost:8084/realms/bancoxyz/protocol/openid-connect/token')

switch $canal
    case web
        set client_id 'bff-web-client'
        set client_secret (set -q OAUTH2_WEB_CLIENT_SECRET; and echo $OAUTH2_WEB_CLIENT_SECRET; or echo 'bancoxyz-web-oauth2-secret-S8-2026')
    case mobile
        set client_id 'bff-mobile-client'
        set client_secret (set -q OAUTH2_MOBILE_CLIENT_SECRET; and echo $OAUTH2_MOBILE_CLIENT_SECRET; or echo 'bancoxyz-mobile-oauth2-secret-S8-2026')
    case atm
        set client_id 'bff-atm-client'
        set client_secret (set -q OAUTH2_ATM_CLIENT_SECRET; and echo $OAUTH2_ATM_CLIENT_SECRET; or echo 'bancoxyz-atm-oauth2-secret-S8-2026')
    case '*'
        echo "ERROR: canal desconocido: $canal" >&2
        exit 1
end

set respuesta (curl -fsS \
    -X POST \
    -u "$client_id:$client_secret" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data 'grant_type=client_credentials' \
    "$token_url")

if test $status -ne 0
    echo "ERROR: Keycloak no entregó token para $client_id." >&2
    exit 1
end

set token (printf '%s' "$respuesta" | jq -er '.access_token')

if test $status -ne 0; or test -z "$token"
    echo "ERROR: la respuesta OAuth2 no contiene access_token." >&2
    exit 1
end

printf '%s\n' "$token"
