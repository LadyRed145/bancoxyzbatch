#!/usr/bin/env bash
set -Eeuo pipefail

# BancoXYZ - Semana 8
# Redeploy final en EC2 desde el mismo commit validado localmente.
# Conserva volúmenes y mantiene Kafka UI / administración del consumer en loopback.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

log() {
    printf '\n===== %s =====\n' "$1"
}

fail() {
    printf '❌ %s\n' "$1" >&2
    exit 1
}

health_of() {
    local service="$1"
    local cid
    cid="$(docker compose ps -q "$service")"

    if [[ -z "$cid" ]]; then
        printf 'missing'
        return
    fi

    docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        "$cid" 2>/dev/null || printf 'unknown'
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
command -v git >/dev/null || fail "Git no está disponible"
command -v docker >/dev/null || fail "Docker no está disponible"
docker compose version >/dev/null || fail "Docker Compose no está disponible"
[[ -f .env ]] || fail "Falta .env en la raíz del proyecto"

if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "El checkout EC2 tiene cambios trackeados. Revísalos antes de actualizar."
fi

printf 'RAM:\n'
free -h
printf '\nDisco raíz:\n'
df -h /

log "ACTUALIZANDO REPOSITORIO"
git pull --ff-only

git status --short

log "VALIDANDO COMPOSE"
docker compose config >/dev/null
printf '✅ docker compose config válido\n'

# La versión anterior utilizaba un único contenedor bancoxyz-kafka y ocupaba 9092.
# Se elimina sólo ese contenedor obsoleto; sus volúmenes no se borran.
if docker ps -a --format '{{.Names}}' | grep -qx 'bancoxyz-kafka'; then
    printf 'Retirando contenedor Kafka monobroker anterior...\n'
    docker rm -f bancoxyz-kafka >/dev/null
fi

log "POSTGRES + KAFKA 3 BROKERS"
docker compose up -d postgres kafka-1 kafka-2 kafka-3

if ! wait_healthy 36 kafka-1 kafka-2 kafka-3; then
    docker compose ps kafka-1 kafka-2 kafka-3
    docker compose logs --tail=120 kafka-1 kafka-2 kafka-3
    fail "El cluster Kafka no alcanzó 3/3 healthy"
fi

printf '✅ Kafka 3/3 healthy\n'

log "CONSTRUYENDO MICROSERVICIOS"
export COMPOSE_PARALLEL_LIMIT=2
docker compose build \
    config-server \
    discovery-server \
    bank-backend \
    retiros-event-consumer \
    bff-web \
    bff-mobile \
    bff-atm

log "INFRAESTRUCTURA COMPLEMENTARIA"
docker compose up -d kafka-ui keycloak config-server discovery-server

if ! wait_healthy 36 keycloak config-server discovery-server; then
    docker compose ps keycloak config-server discovery-server
    fail "Infraestructura complementaria no quedó healthy"
fi

log "MICROSERVICIOS"
docker compose up -d \
    bank-backend \
    retiros-event-consumer \
    bff-web \
    bff-mobile \
    bff-atm

if ! wait_healthy 48 \
    postgres \
    kafka-1 kafka-2 kafka-3 \
    keycloak config-server discovery-server \
    bank-backend retiros-event-consumer \
    bff-web bff-mobile bff-atm; then

    docker compose ps
    fail "Uno o más servicios con healthcheck no alcanzaron healthy"
fi

log "LIMPIANDO ORPHANS SIN BORRAR VOLUMENES"
docker compose up -d --remove-orphans

log "KAFKA UI"
if ! curl -fsS --connect-timeout 5 --max-time 15 http://127.0.0.1:8090 >/dev/null; then
    docker compose logs --tail=80 kafka-ui
    fail "Kafka UI no responde en loopback:8090"
fi
printf '✅ Kafka UI responde en 127.0.0.1:8090\n'

log "ESTADO FINAL"
docker compose ps

printf '\nRAM final:\n'
free -h

printf '\n==========================================================\n'
printf '✅ REDEPLOY EC2 COMPLETADO\n'
printf '   12 servicios con healthcheck healthy\n'
printf '   Kafka UI running + HTTP 200\n'
printf '   Volúmenes conservados\n'
printf '==========================================================\n'
