#!/usr/bin/env bash
set -Eeuo pipefail

# BancoXYZ EFT Semana 9: prueba de escalado horizontal EN UNA EC2.
# Opera EXCLUSIVAMENTE sobre docker-compose.s9.ec2.yml (proyecto bancoxyz-s9).
# No modifica CSV, .env, Semana 8, tablas SQL, redes ni volúmenes.
# No realiza docker compose down, down -v, prune, reset ni clean.

ROOT="$HOME/bancoxyzbatch-s9"
COMPOSE="$ROOT/docker-compose.s9.ec2.yml"
SERVICIOS=(cuentas-service clientes-service pagos-service)
MODE="${1:---probar}"

error() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '\n===== %s =====\n' "$*"; }

[[ "$MODE" == '--probar' || "$MODE" == '--restaurar' ]] || error 'Uso: bash probar_escalado_horizontal_ec2_s9.sh [--probar|--restaurar]'
[[ -d "$ROOT" && -f "$COMPOSE" ]] || error "Falta el proyecto S9 o el Compose: $ROOT"
cd "$ROOT"
command -v docker >/dev/null || error 'Falta Docker'
command -v python3 >/dev/null || error 'Falta python3'
docker info >/dev/null 2>&1 || error 'Docker no responde'
[[ -f .env ]] || error 'Falta el .env privado de Semana 9'

compose() { docker compose -f "$COMPOSE" "$@"; }
compose config --quiet || error 'Compose S9 no valido'

# Verifica el proyecto, que los tres servicios admiten réplicas y que
# ninguno fija container_name ni expone puertos host (causaría colisiones).
compose config --format json | python3 -c '
import json,sys
c=json.load(sys.stdin)
assert c.get("name")=="bancoxyz-s9", "Proyecto distinto a bancoxyz-s9"
for name in ("cuentas-service", "clientes-service", "pagos-service"):
    s=c["services"][name]
    assert not s.get("container_name"), f"{name} tiene container_name fijo"
    assert not s.get("ports"), f"{name} expone puerto fijo del host"
print("OK: Proyecto exclusivo bancoxyz-s9; servicios escalables sin puertos host fijos")
' || error 'La configuración no está aislada para el escalado'

# Si hay contenedores activos de Semana 8, NO comenzamos: memoria limitada.
if [[ -n "$(docker ps -q --filter label=com.docker.compose.project=bancoxyzbatch)" ]]; then
    error 'Semana 8 sigue ejecutándose. Detenla primero con el comando indicado, sin borrar volúmenes.'
fi

if [[ "$MODE" == '--restaurar' ]]; then
    info 'VOLVER A UNA RÉPLICA POR MICROSERVICIO (CONSERVANDO BD Y KEYCLOAK)'
    compose up -d --no-deps --no-build \
      --scale cuentas-service=1 \
      --scale clientes-service=1 \
      --scale pagos-service=1 "${SERVICIOS[@]}"
    compose ps "${SERVICIOS[@]}"
    info 'SEMANA 9: REPLICAS RESTAURADAS A 1/1/1'
    exit 0
fi

info 'RECURSOS EC2 Y PRECONDICIONES'
free -h
df -h /
TOTAL_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
DISP_KB="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
DISCO_KB="$(df -Pk / | awk 'NR==2 {print $4}')"
(( TOTAL_KB >= 6000000 )) || error 'Esta prueba conjunta exige una EC2 con al menos ~6 GiB de RAM total'
(( DISP_KB >= 3000000 )) || error 'Menos de ~3 GiB disponibles: no arrancamos las réplicas para evitar OOM'
(( DISCO_KB >= 8000000 )) || error 'Menos de ~8 GB libres en disco'

info 'VERIFICANDO INFRAESTRUCTURA S9 EXISTENTE'
for servicio in postgres keycloak; do
    ids="$(compose ps -q "$servicio")"
    [[ -n "$ids" ]] || error "El servicio S9 $servicio no esta iniciado"
    for cid in $ids; do
        estado="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid")"
        [[ "$estado" == healthy ]] || error "S9 $servicio no esta healthy (estado: $estado)"
    done
done

info 'CONSTRUYENDO IMAGENES (UNA A UNA PARA PROTEGER LA RAM)'
# BuildKit podría paralelizar etapas dentro de un build; una imagen por vez.
export COMPOSE_PARALLEL_LIMIT=1
for servicio in config-server discovery-server "${SERVICIOS[@]}"; do
    printf '\nConstruyendo %s ...\n' "$servicio"
    compose build "$servicio" || error "Falló la compilación de $servicio; revisar Dockerfile y logs sin tocar Semana 8"
done

info 'INICIANDO CONFIG SERVER Y EUREKA'
compose up -d --no-build config-server discovery-server || error 'No arrancaron Config Server/Eureka'

# Esperar hasta que todos los contenedores actuales de cada servicio estén healthy.
esperar() {
    local n="$1" esperado="$2" max="${3:-48}" paso ids cid estado bien vuelta
    for ((vuelta=1; vuelta<=max; vuelta++)); do
        ids="$(docker ps -aq \
            --filter "label=com.docker.compose.project=bancoxyz-s9" \
            --filter "label=com.docker.compose.service=$n")"
        bien=0
        total=0
        for cid in $ids; do
            total=$((total+1))
            estado="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || true)"
            [[ "$estado" == healthy ]] && bien=$((bien+1))
        done
        if (( total == esperado && bien == esperado )); then
            printf 'OK: %s -> %s/%s contenedores HEALTHY\n' "$n" "$bien" "$esperado"
            return 0
        fi
        if (( vuelta % 6 == 0 )); then
            printf 'Esperando %s: healthy=%s, encontrados=%s, esperados=%s\n' "$n" "$bien" "$total" "$esperado"
        fi
        sleep 5
    done
    return 1
}

for svc in config-server discovery-server; do
    esperar "$svc" 1 36 || error "$svc no alcanzo estado HEALTHY (ver: docker compose -f '$COMPOSE' ps)"
done

info 'ESCALADO BASE: 1 RÉPLICA POR SERVICIO'
compose up -d --no-build --no-deps \
    --scale cuentas-service=1 \
    --scale clientes-service=1 \
    --scale pagos-service=1 "${SERVICIOS[@]}" || error 'No se pudo iniciar el escalado base'
for svc in "${SERVICIOS[@]}"; do
    esperar "$svc" 1 48 || error "Falló el arranque base de $svc; revisar logs"
done

info 'ESCALADO HORIZONTAL: 2 RÉPLICAS PARA CADA UNO DE LOS 3 MICROSERVICIOS'
compose up -d --no-build --no-deps \
    --scale cuentas-service=2 \
    --scale clientes-service=2 \
    --scale pagos-service=2 "${SERVICIOS[@]}" || error 'Falló docker compose --scale'
for svc in "${SERVICIOS[@]}"; do
    esperar "$svc" 2 48 || error "$svc no alcanzo 2 replicas saludables"
done

info 'EUREKA: VALIDAR DOS INSTANCIAS UP POR SERVICIO'
# Esperamos al registro dinámico: puede tardar más que el healthcheck local.
python3 - <<'PY'
import sys,time,urllib.request,xml.etree.ElementTree as ET
apps={"cuentas-service":"CUENTAS-SERVICE","clientes-service":"CLIENTES-SERVICE","pagos-service":"PAGOS-SERVICE"}
base="http://127.0.0.1:18761/eureka/apps/"
pendientes=dict(apps)
for intento in range(30):
    faltantes={}
    for servicio,appid in pendientes.items():
        try:
            req=urllib.request.Request(base+appid,headers={"Accept":"application/xml"})
            with urllib.request.urlopen(req,timeout=5) as r:
                root=ET.fromstring(r.read())
            up=[e for e in root.findall(".//instance") if e.findtext("status")=="UP"]
            if len(up)>=2:
                ids=[e.findtext("instanceId", "?") for e in up]
                print(f"OK: Eureka {servicio} -> {len(up)} instancias UP; IDs distintos: {len(set(ids))>=2}")
                if len(set(ids))<2:
                    faltantes[servicio]=appid
            else:
                faltantes[servicio]=appid
        except Exception:
            faltantes[servicio]=appid
    pendientes=faltantes
    if not pendientes:
        break
    time.sleep(5)
if pendientes:
    print("PENDIENTE: Eureka no confirmó dos instancias UP para:", ", ".join(pendientes))
    sys.exit(2)
PY

echo
info 'EVIDENCIA FINAL: 6 RÉPLICAS HEALTHY + 3 SERVICIOS CON 2 REGISTROS EUREKA'
compose ps config-server discovery-server "${SERVICIOS[@]}"
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}' \
  $(docker ps -q --filter label=com.docker.compose.project=bancoxyz-s9 \
    --filter label=com.docker.compose.service=cuentas-service \
    --filter label=com.docker.compose.service=clientes-service \
    --filter label=com.docker.compose.service=pagos-service) || true
free -h
printf '\nEXITO: escalado horizontal 2/2/2 comprobado en una EC2; esto NO demuestra alta disponibilidad multi-AZ.\n'
printf 'Para reducir memoria sin borrar datos: bash "%s" --restaurar\n' "$0"
