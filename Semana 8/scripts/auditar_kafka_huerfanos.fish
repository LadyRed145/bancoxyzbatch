#!/usr/bin/env fish

# ============================================================
# BancoXYZ - Semana 8
# Auditoría de limpieza Kafka después de separar el consumidor.
# No modifica archivos.
# ============================================================

set -l ROOT (cd (dirname (status --current-filename))/../..; pwd)
set -l BACKEND "$ROOT/Semana 8/bank-backend"
set -l CONSUMER "$ROOT/Semana 8/retiros-event-consumer"
set -l COMPOSE "$ROOT/docker-compose.yml"
set -l ROOT_POM "$ROOT/pom.xml"
set -l ERRORS 0

function ok
    echo "✅ $argv"
end

function fail
    echo "❌ $argv"
    set -g ERRORS (math $ERRORS + 1)
end

echo
echo "======================================================"
echo " BANCOXYZ - AUDITORÍA DE LIMPIEZA KAFKA / SEMANA 8"
echo "======================================================"

# 1) Consumer antiguo eliminado.
set -l OLD "$BACKEND/src/main/java/cl/duoc/bancoxyz/backend/kafka/RetiroKafkaConsumer.java"
if not test -f "$OLD"
    ok "Consumer antiguo eliminado de bank-backend"
else
    fail "RetiroKafkaConsumer.java antiguo todavía existe"
end

# 2) Cero listeners en bank-backend.
set -l OLD_LISTENERS (grep -R -l '@KafkaListener' "$BACKEND/src/main/java" 2>/dev/null)
if test (count $OLD_LISTENERS) -eq 0
    ok "bank-backend contiene 0 @KafkaListener"
else
    fail "bank-backend todavía contiene @KafkaListener"
    printf '   %s\n' $OLD_LISTENERS
end

# 3) Cero propiedades spring.kafka.consumer.* en backend.
set -l BACKEND_PROPS "$BACKEND/src/main/resources/application.properties"
set -l OLD_PROPS (grep -n '^spring\.kafka\.consumer\.' "$BACKEND_PROPS" 2>/dev/null)
if test (count $OLD_PROPS) -eq 0
    ok "bank-backend contiene 0 propiedades consumer huérfanas"
else
    fail "Quedaron propiedades spring.kafka.consumer.* en bank-backend"
    printf '   %s\n' $OLD_PROPS
end

# 4) Producer sigue donde corresponde.
set -l PRODUCERS (find "$BACKEND/src/main/java" -type f -name 'RetiroKafkaProducer.java' 2>/dev/null)
if test (count $PRODUCERS) -eq 1
    ok "Existe exactamente 1 RetiroKafkaProducer en bank-backend"
else
    fail "Cantidad inesperada de RetiroKafkaProducer: "(count $PRODUCERS)
end

# 5) Un único listener en el nuevo microservicio.
set -l NEW_LISTENERS (grep -R -l '@KafkaListener' "$CONSUMER/src/main/java" 2>/dev/null)
if test (count $NEW_LISTENERS) -eq 1
    ok "Existe exactamente 1 @KafkaListener en retiros-event-consumer"
else
    fail "Cantidad inesperada de @KafkaListener en nuevo consumer: "(count $NEW_LISTENERS)
end

# 6) Módulo raíz no duplicado.
set -l MODULE_COUNT (grep -c '<module>Semana 8/retiros-event-consumer</module>' "$ROOT_POM" 2>/dev/null)
if test "$MODULE_COUNT" = "1"
    ok "Módulo retiros-event-consumer registrado una sola vez"
else
    fail "Módulo retiros-event-consumer aparece $MODULE_COUNT veces en pom.xml"
end

# 7) Servicio Compose no duplicado.
set -l SERVICE_COUNT (grep -c '^  retiros-event-consumer:' "$COMPOSE" 2>/dev/null)
if test "$SERVICE_COUNT" = "1"
    ok "Servicio retiros-event-consumer registrado una sola vez en Compose"
else
    fail "Servicio retiros-event-consumer aparece $SERVICE_COUNT veces en Compose"
end

# 8) La API administrativa usa 8091 -> 8090 y queda en loopback por defecto.
if grep -q '8091:8090' "$COMPOSE"
    ok "API administrativa del consumer publicada en 8091"
else
    fail "Falta publicación 8091 -> 8090 para administración del listener"
end

# 9) El nuevo servicio conserva healthcheck interno.
if grep -q 'localhost:8090/actuator/health' "$COMPOSE"
    ok "Healthcheck interno del consumer presente"
else
    fail "Falta healthcheck interno del consumer"
end

# 10) target/ puede existir después de compilar, pero nunca debe estar versionado.
set -l TRACKED_TARGETS (git -C "$ROOT" ls-files -- 'Semana 8/retiros-event-consumer/target/**' 2>/dev/null)
if test (count $TRACKED_TARGETS) -eq 0
    ok "target/ del consumer no está versionado"
else
    fail "Hay artefactos target/ versionados en retiros-event-consumer"
    printf '   %s\n' $TRACKED_TARGETS
end

# 11) Listener Kafka identificable para pausa/reanudación.
if grep -q 'id = KafkaConsumerControlService.LISTENER_ID' "$CONSUMER/src/main/java/cl/duoc/bancoxyz/retirosconsumer/kafka/RetiroKafkaConsumer.java"
    ok "@KafkaListener tiene id administrable"
else
    fail "Falta id administrable en @KafkaListener"
end

# 12) API administrativa protegida por Spring Security.
if test -f "$CONSUMER/src/main/java/cl/duoc/bancoxyz/retirosconsumer/config/SecurityConfig.java"
    ok "Spring Security presente en retiros-event-consumer"
else
    fail "Falta SecurityConfig en retiros-event-consumer"
end

# 13) Docker Compose válido.
if type -q docker
    docker compose -f "$COMPOSE" config >/dev/null 2>&1
    if test $status -eq 0
        ok "docker-compose.yml válido"
    else
        fail "docker-compose.yml no valida"
    end
end

echo "------------------------------------------------------"
if test $ERRORS -eq 0
    echo "✅ AUDITORÍA LIMPIA: 0 HUÉRFANOS / 0 DUPLICADOS"
else
    echo "⚠️  AUDITORÍA: $ERRORS problema(s) requieren revisión"
end
echo "======================================================"

exit $ERRORS
