#!/usr/bin/env fish

# BancoXYZ - Semana 8
# Verifica cluster Kafka: 3 brokers, 3 particiones, RF=3 y Kafka UI.

set -l ROOT (dirname (dirname (dirname (status --current-filename))))
cd "$ROOT"; or exit 1

set -l BROKERS bancoxyz-kafka-1 bancoxyz-kafka-2 bancoxyz-kafka-3
set -l TOPIC "bancoxyz.retiros"
set -l KAFKA_MAIN "bancoxyz-kafka-1"
set -l KAFKA_UI "bancoxyz-kafka-ui"
set -l PASS 1

function health_container --argument-names container
    docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null
end

echo "=========================================================="
echo " BANCOXYZ - CLUSTER KAFKA / SEMANA 8"
echo "=========================================================="

echo
echo "1. BROKERS"
for BROKER in $BROKERS
    set -l HEALTH (health_container "$BROKER")
    echo "   $BROKER ........ $HEALTH"
    if test "$HEALTH" != "healthy"
        set PASS 0
    end
end

echo
echo "2. BROKERS REGISTRADOS EN EL CLUSTER"
set -l BROKER_LINES (docker exec "$KAFKA_MAIN" \
    /opt/kafka/bin/kafka-broker-api-versions.sh \
    --bootstrap-server localhost:19092 2>/dev/null \
    | grep -E '^kafka-[123]:')

set -l BROKER_COUNT (count $BROKER_LINES)
echo "   Brokers detectados ..... $BROKER_COUNT"

if test "$BROKER_COUNT" -ne 3
    set PASS 0
end

echo
echo "3. TOPIC"
set -l TOPIC_DESC (docker exec "$KAFKA_MAIN" \
    /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:19092 \
    --describe \
    --topic "$TOPIC" 2>/dev/null)

echo "$TOPIC_DESC"

set -l PARTITIONS (string match -r 'PartitionCount: [0-9]+' -- "$TOPIC_DESC" | string replace 'PartitionCount: ' '')
set -l RF (string match -r 'ReplicationFactor: [0-9]+' -- "$TOPIC_DESC" | string replace 'ReplicationFactor: ' '')

if test "$PARTITIONS" != "3"
    set PASS 0
end

if test "$RF" != "3"
    set PASS 0
end

echo
echo "4. KAFKA UI"
set -l UI_HEALTH (health_container "$KAFKA_UI")
echo "   Container .............. $UI_HEALTH"
echo "   URL local .............. http://localhost:8090"

if test "$UI_HEALTH" != "healthy"; and test "$UI_HEALTH" != "running"
    set PASS 0
end

echo
echo "5. RESULTADO"
if test $PASS -eq 1
    echo "✅ CLUSTER KAFKA FUNCIONAL"
    echo "   3 brokers + 3 particiones + RF=3 + Kafka UI"
else
    echo "❌ CLUSTER KAFKA REQUIERE REVISIÓN"
end
echo "=========================================================="

functions -e health_container

if test $PASS -eq 1
    exit 0
else
    exit 1
end
