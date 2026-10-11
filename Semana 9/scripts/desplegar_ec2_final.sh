#!/usr/bin/env bash
set -Eeuo pipefail

# BancoXYZ - Semana 9
# Despliegue reproducible en una EC2 con Caddy, HTTPS valido para Keycloak
# y Kafka local o externo configurable mediante .env.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

compose() {
    docker compose --profile ec2 "$@"
}

log() {
    printf '\n===== %s =====\n' "$1"
}

fail() {
    printf '❌ %s\n' "$1" >&2
    exit 1
}

require_value() {
    local name="$1"
    local value="${!name:-}"

    [[ -n "$value" ]] || fail "Falta $name en .env"
    [[ "$value" != *CHANGE_ME* ]] || fail "$name todavia contiene CHANGE_ME"
}

dotenv_get() {
    local name="$1"
    awk -F= -v key="$name" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' .env
}

health_of() {
    local service="$1"
    local -a cids
    mapfile -t cids < <(compose ps -q "$service")

    if [[ "${#cids[@]}" -eq 0 ]]; then
        printf 'missing'
        return
    fi

    local cid
    for cid in "${cids[@]}"; do
        local status
        status="$(docker inspect \
            --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
            "$cid" 2>/dev/null || printf 'unknown')"

        if [[ "$status" != "healthy" ]]; then
            printf '%s' "$status"
            return
        fi
    done

    printf 'healthy'
}

wait_healthy() {
    local max_attempts="$1"
    shift
    local services=("$@")

    for attempt in $(seq 1 "$max_attempts"); do
        local healthy=0
        local service

        for service in "${services[@]}"; do
            if [[ "$(health_of "$service")" == "healthy" ]]; then
                healthy=$((healthy + 1))
            fi
        done

        printf 'Intento %s/%s -> %s/%s healthy\n' \
            "$attempt" "$max_attempts" "$healthy" "${#services[@]}"

        if [[ "$healthy" -eq "${#services[@]}" ]]; then
            return 0
        fi

        sleep 5
    done

    return 1
}

log "PRECHECK"
command -v git >/dev/null || fail "Git no esta disponible"
command -v docker >/dev/null || fail "Docker no esta disponible"
command -v curl >/dev/null || fail "curl no esta disponible"
docker compose version >/dev/null || fail "Docker Compose v2 no esta disponible"
[[ -f .env ]] || fail "Falta .env. Copia .env.ec2.example y completa sus valores."

POSTGRES_DB="$(dotenv_get POSTGRES_DB)"
POSTGRES_USER="$(dotenv_get POSTGRES_USER)"
POSTGRES_PASSWORD="$(dotenv_get POSTGRES_PASSWORD)"
KEYCLOAK_DOMAIN="$(dotenv_get KEYCLOAK_DOMAIN)"
TLS_EMAIL="$(dotenv_get TLS_EMAIL)"
KEYCLOAK_ADMIN_PASSWORD="$(dotenv_get KEYCLOAK_ADMIN_PASSWORD)"
OAUTH2_WEB_CLIENT_SECRET="$(dotenv_get OAUTH2_WEB_CLIENT_SECRET)"
OAUTH2_MOBILE_CLIENT_SECRET="$(dotenv_get OAUTH2_MOBILE_CLIENT_SECRET)"
OAUTH2_ATM_CLIENT_SECRET="$(dotenv_get OAUTH2_ATM_CLIENT_SECRET)"
KAFKA_MODE="$(dotenv_get KAFKA_MODE)"
KAFKA_BOOTSTRAP_SERVERS="$(dotenv_get KAFKA_BOOTSTRAP_SERVERS)"
KAFKA_SECURITY_PROTOCOL="$(dotenv_get KAFKA_SECURITY_PROTOCOL)"

POSTGRES_DB="${POSTGRES_DB:-bancoxyz}"
POSTGRES_USER="${POSTGRES_USER:-bancoxyz}"

require_value POSTGRES_PASSWORD
require_value KEYCLOAK_DOMAIN
require_value TLS_EMAIL
require_value KEYCLOAK_ADMIN_PASSWORD
require_value OAUTH2_WEB_CLIENT_SECRET
require_value OAUTH2_MOBILE_CLIENT_SECRET
require_value OAUTH2_ATM_CLIENT_SECRET

KAFKA_MODE="${KAFKA_MODE:-local}"
[[ "$KAFKA_MODE" == "local" || "$KAFKA_MODE" == "external" ]] \
    || fail "KAFKA_MODE debe ser local o external"

if [[ "$KAFKA_MODE" == "external" ]]; then
    require_value KAFKA_BOOTSTRAP_SERVERS
    [[ "${KAFKA_SECURITY_PROTOCOL:-}" == "SSL" ]] \
        || fail "Kafka externo debe usar KAFKA_SECURITY_PROTOCOL=SSL"
fi

if ! getent hosts "$KEYCLOAK_DOMAIN" >/dev/null; then
    fail "El dominio $KEYCLOAK_DOMAIN todavia no resuelve por DNS"
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "El checkout EC2 tiene cambios trackeados. Revisalos antes de actualizar."
fi

printf 'Dominio Keycloak: %s\n' "$KEYCLOAK_DOMAIN"
printf 'Modo Kafka: %s\n' "$KAFKA_MODE"
printf 'RAM:\n'
free -h
printf '\nDisco raiz:\n'
df -h /

log "ACTUALIZANDO REPOSITORIO"
git pull --ff-only
git status --short

log "VALIDANDO COMPOSE"
compose config --quiet
printf '✅ Configuracion del perfil EC2 valida\n'

log "POSTGRESQL"
compose up -d postgres
if ! wait_healthy 24 postgres; then
    compose logs --tail=120 postgres
    fail "PostgreSQL no alcanzo el estado healthy"
fi

# 01_schema.sql se aplica automaticamente en volumenes nuevos. Esta sentencia
# tambien cubre redeploys sobre un volumen creado antes de incorporar Keycloak DB.
compose exec -T postgres psql \
    --set ON_ERROR_STOP=1 \
    --username "${POSTGRES_USER:-bancoxyz}" \
    --dbname "${POSTGRES_DB:-bancoxyz}" \
    --command 'CREATE SCHEMA IF NOT EXISTS keycloak;'

if [[ "$KAFKA_MODE" == "local" ]]; then
    log "KAFKA LOCAL - TRES BROKERS EN ESTA EC2"
    compose up -d kafka-1 kafka-2 kafka-3

    if ! wait_healthy 36 kafka-1 kafka-2 kafka-3; then
        compose ps kafka-1 kafka-2 kafka-3
        compose logs --tail=120 kafka-1 kafka-2 kafka-3
        fail "El cluster Kafka local no alcanzo 3/3 healthy"
    fi

    printf '✅ Kafka local 3/3 healthy\n'
else
    log "KAFKA EXTERNO"
    printf 'Bootstrap brokers: %s\n' "$KAFKA_BOOTSTRAP_SERVERS"
    printf 'Protocolo: %s\n' "$KAFKA_SECURITY_PROTOCOL"
fi

log "CONSTRUYENDO MICROSERVICIOS"
export COMPOSE_PARALLEL_LIMIT=2
compose build \
    config-server \
    discovery-server \
    bank-backend \
    retiros-event-consumer \
    cuentas-service \
    clientes-service \
    pagos-service \
    bff-web \
    bff-mobile \
    bff-atm

log "KEYCLOAK PRODUCTIVO + CADDY"
infra_services=(keycloak config-server discovery-server caddy)
if [[ "$KAFKA_MODE" == "local" ]]; then
    infra_services+=(kafka-ui)
fi
compose up -d "${infra_services[@]}"

if ! wait_healthy 48 keycloak config-server discovery-server caddy; then
    compose ps keycloak config-server discovery-server caddy
    compose logs --tail=120 keycloak caddy
    fail "Keycloak, Caddy o la infraestructura base no quedaron healthy"
fi

log "MICROSERVICIOS"
app_services=(
    bank-backend
    retiros-event-consumer
    cuentas-service
    clientes-service
    pagos-service
    bff-web
    bff-mobile
    bff-atm
)
compose up -d "${app_services[@]}"

health_services=(
    postgres
    keycloak
    config-server
    discovery-server
    caddy
    bank-backend
    retiros-event-consumer
    cuentas-service
    clientes-service
    pagos-service
    bff-web
    bff-mobile
    bff-atm
)
if [[ "$KAFKA_MODE" == "local" ]]; then
    health_services+=(kafka-1 kafka-2 kafka-3)
fi

if ! wait_healthy 60 "${health_services[@]}"; then
    compose ps
    fail "Uno o mas servicios no alcanzaron el estado healthy"
fi

log "VALIDANDO HTTPS PUBLICO"
discovery_url="https://${KEYCLOAK_DOMAIN}/realms/bancoxyz/.well-known/openid-configuration"
curl --fail --silent --show-error \
    --connect-timeout 10 \
    --max-time 30 \
    "$discovery_url" >/dev/null \
    || fail "Keycloak no responde con un certificado TLS valido en $discovery_url"
printf '✅ Keycloak responde por HTTPS valido: %s\n' "$discovery_url"

if [[ "$KAFKA_MODE" == "local" ]]; then
    log "KAFKA UI"
    curl --fail --silent --show-error \
        --connect-timeout 5 \
        --max-time 15 \
        http://127.0.0.1:8090 >/dev/null \
        || fail "Kafka UI no responde en loopback:8090"
    printf '✅ Kafka UI responde en 127.0.0.1:8090\n'
fi

log "ESTADO FINAL"
compose ps

printf '\nRAM final:\n'
free -h

printf '\n==========================================================\n'
printf '✅ DESPLIEGUE EC2 COMPLETADO\n'
printf '   Keycloak productivo detras de Caddy + HTTPS valido\n'
printf '   Kafka: %s\n' "$KAFKA_MODE"
printf '   Volumenes conservados\n'
printf '==========================================================\n'
