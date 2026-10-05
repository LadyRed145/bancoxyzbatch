#!/usr/bin/env fish

# BancoXYZ - Semana 8
# Evidencia Kafka entre microservicios para cluster de 3 brokers.
# Valida topologia, producer, consumer, offsets agregados y lag total.

set -l ROOT (dirname (dirname (dirname (status --current-filename))))
cd "$ROOT"; or exit 1

set -l CONSUMER "bancoxyz-retiros-event-consumer"
set -l KAFKA_1 "bancoxyz-kafka-1"
set -l KAFKA_2 "bancoxyz-kafka-2"
set -l KAFKA_3 "bancoxyz-kafka-3"
set -l GROUP "bancoxyz-retiros-group"
set -l TOPIC "bancoxyz.retiros"
set -l TMP_RETIRO (mktemp /tmp/bancoxyz_kafka_retiro_XXXXXX)

function obtener_offsets --argument-names kafka group topic
    # Un rebalanceo breve puede dejar kafka-consumer-groups sin filas durante
    # unos segundos. Reintento antes de declarar el grupo como no disponible.
    for intento in (seq 1 10)
        set -l RESULT (docker exec "$kafka" \
            /opt/kafka/bin/kafka-consumer-groups.sh \
            --bootstrap-server localhost:19092 \
            --describe \
            --group "$group" 2>/dev/null \
            | awk -v topic="$topic" '''
                {
                    topic_col = 0

                    for (i = 1; i <= NF; i++) {
                        if ($i == topic) {
                            topic_col = i
                            break
                        }
                    }

                    if (topic_col > 0) {
                        partition = $(topic_col + 1)
                        current = $(topic_col + 2)
                        end = $(topic_col + 3)
                        lag_value = $(topic_col + 4)

                        if (partition ~ /^[0-9]+$/) {
                            rows++

                            if (current == "-" || current == "") current = 0
                            if (end == "-" || end == "") end = 0
                            if (lag_value == "-" || lag_value == "") lag_value = 0

                            if (current ~ /^[0-9]+$/) current_total += current
                            if (end ~ /^[0-9]+$/) end_total += end
                            if (lag_value ~ /^[0-9]+$/) lag_total += lag_value
                        }
                    }
                }
                END {
                    if (rows > 0) {
                        print current_total " " end_total " " lag_total " " rows
                    }
                }
            ''')

        if test -n "$RESULT"
            echo "$RESULT"
            return 0
        end

        sleep 1
    end

    echo "N/A N/A N/A 0"
    return 1
end

function describir_topic --argument-names kafka topic
    docker exec "$kafka" \
        /opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server localhost:19092 \
        --describe \
        --topic "$topic" 2>/dev/null
end

function health_container --argument-names container
    docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        "$container" 2>/dev/null
end

echo "=========================================================="
echo " BANCOXYZ - EVIDENCIA KAFKA ENTRE MICROSERVICIOS"
echo "=========================================================="

echo
echo "1. ARQUITECTURA"
echo "   BFF ATM -> Bank Backend -> Kafka -> Retiros Consumer"
echo "   Topic ................. $TOPIC"
echo "   Consumer Group ........ $GROUP"

set -l KAFKA1_H (health_container "$KAFKA_1")
set -l KAFKA2_H (health_container "$KAFKA_2")
set -l KAFKA3_H (health_container "$KAFKA_3")
set -l BACKEND_H (health_container bancoxyz-bank-backend)
set -l CONSUMER_H (health_container "$CONSUMER")

echo
echo "2. ESTADO DE COMPONENTES"
echo "   Kafka Broker 1 ........ $KAFKA1_H"
echo "   Kafka Broker 2 ........ $KAFKA2_H"
echo "   Kafka Broker 3 ........ $KAFKA3_H"
echo "   Bank Backend .......... $BACKEND_H  [PRODUCER]"
echo "   Retiros Consumer ...... $CONSUMER_H  [CONSUMER]"

set -l PARTITION_COUNT (describir_topic "$KAFKA_1" "$TOPIC" \
    | awk '
        match($0, /PartitionCount:[[:space:]]*[0-9]+/) {
            value = substr($0, RSTART, RLENGTH)
            sub(/PartitionCount:[[:space:]]*/, "", value)
            print value
            exit
        }
    ')

set -l REPLICATION_FACTOR (describir_topic "$KAFKA_1" "$TOPIC" \
    | awk '
        match($0, /ReplicationFactor:[[:space:]]*[0-9]+/) {
            value = substr($0, RSTART, RLENGTH)
            sub(/ReplicationFactor:[[:space:]]*/, "", value)
            print value
            exit
        }
    ')

if test -z "$PARTITION_COUNT"
    set PARTITION_COUNT 0
end

if test -z "$REPLICATION_FACTOR"
    set REPLICATION_FACTOR 0
end

set -l BROKERS_HEALTHY 0
for H in "$KAFKA1_H" "$KAFKA2_H" "$KAFKA3_H"
    if test "$H" = "healthy"
        set BROKERS_HEALTHY (math $BROKERS_HEALTHY + 1)
    end
end

echo
echo "2B. TOPOLOGIA KAFKA"
echo "   Brokers saludables .... $BROKERS_HEALTHY/3"
echo "   Topic .................. $TOPIC"
echo "   Particiones ............ $PARTITION_COUNT"
echo "   Replication Factor ..... $REPLICATION_FACTOR"

set -l BEFORE (obtener_offsets "$KAFKA_1" "$GROUP" "$TOPIC")
set -l B (string split ' ' -- "$BEFORE")
set -l BEFORE_CURRENT $B[1]
set -l BEFORE_END $B[2]
set -l BEFORE_LAG $B[3]
set -l BEFORE_PARTITIONS $B[4]

echo
echo "3. CONSUMER GROUP - ANTES"
echo "   Current Offset ........ $BEFORE_CURRENT"
echo "   Log End Offset ........ $BEFORE_END"
echo "   Lag total ............. $BEFORE_LAG"
echo "   Particiones ........... $BEFORE_PARTITIONS"

set -l START_TS (date -u +%Y-%m-%dT%H:%M:%SZ)

fish "Semana 8/scripts/verificar_retiro_controlado.fish" >"$TMP_RETIRO" 2>&1
set -l RETIRO_STATUS $status

sleep 2

set -l AFTER (obtener_offsets "$KAFKA_1" "$GROUP" "$TOPIC")
set -l A (string split ' ' -- "$AFTER")
set -l AFTER_CURRENT $A[1]
set -l AFTER_END $A[2]
set -l AFTER_LAG $A[3]
set -l AFTER_PARTITIONS $A[4]

set -l PUBLICADO (docker logs bancoxyz-bank-backend --since "$START_TS" 2>&1 \
    | grep -m1 'EVENTO KAFKA PUBLICADO CORRECTAMENTE')

set -l CONSUMIDO (docker logs "$CONSUMER" --since "$START_TS" 2>&1 \
    | grep -m1 'EVENTO_KAFKA_CONSUMIDO')

set -l SALDO_ANTES (grep -m1 'Saldo antes:' "$TMP_RETIRO")
set -l RETIRO (grep -m1 '^Retiro:' "$TMP_RETIRO")
set -l SALDO_DESPUES (grep -m1 'Saldo después:' "$TMP_RETIRO")

echo
echo "4. OPERACION BANCARIA REAL"
if test $RETIRO_STATUS -eq 0
    echo "   $SALDO_ANTES"
    echo "   $RETIRO"
    echo "   $SALDO_DESPUES"
else
    echo "   Retiro controlado .......... FALLÓ ❌"
    echo "   Salida del helper:"
    sed 's/^/      /' "$TMP_RETIRO"
end

echo
echo "5. MENSAJERIA ASINCRONA"
if test -n "$PUBLICADO"
    echo "   Producer ............... EVENTO PUBLICADO ✅"
else
    echo "   Producer ............... NO DETECTADO ❌"
end

if test -n "$CONSUMIDO"
    echo "   Consumer ............... EVENTO CONSUMIDO ✅"
else
    echo "   Consumer ............... NO DETECTADO ❌"
end

echo
echo "6. CONSUMER GROUP - DESPUES"
echo "   Current Offset ........ $AFTER_CURRENT"
echo "   Log End Offset ........ $AFTER_END"
echo "   Lag total ............. $AFTER_LAG"
echo "   Particiones ........... $AFTER_PARTITIONS"
echo "   Avance ................. $BEFORE_CURRENT -> $AFTER_CURRENT"

set -l PASS 1

if test "$KAFKA1_H" != "healthy"; set PASS 0; end
if test "$KAFKA2_H" != "healthy"; set PASS 0; end
if test "$KAFKA3_H" != "healthy"; set PASS 0; end
if test "$BACKEND_H" != "healthy"; set PASS 0; end
if test "$CONSUMER_H" != "healthy"; set PASS 0; end
if test "$PARTITION_COUNT" != "3"; set PASS 0; end
if test "$REPLICATION_FACTOR" != "3"; set PASS 0; end
if test "$AFTER_PARTITIONS" != "3"; set PASS 0; end
if test $RETIRO_STATUS -ne 0; set PASS 0; end
if test -z "$PUBLICADO"; set PASS 0; end
if test -z "$CONSUMIDO"; set PASS 0; end
if test "$AFTER_LAG" != "0"; set PASS 0; end

if string match -qr '^[0-9]+$' -- "$BEFORE_CURRENT"; and string match -qr '^[0-9]+$' -- "$AFTER_CURRENT"
    if test "$AFTER_CURRENT" -le "$BEFORE_CURRENT"
        set PASS 0
    end
else
    set PASS 0
end

echo
echo "7. VALIDACION"
if test -n "$PUBLICADO"
    echo "   Backend produce evento .......... ✅"
else
    echo "   Backend produce evento .......... ❌"
end
if test -n "$PUBLICADO"; and test -n "$CONSUMIDO"
    echo "   Kafka transporta evento ......... ✅"
else
    echo "   Kafka transporta evento ......... ❌"
end
if test "$CONSUMER_H" = "healthy"
    echo "   Microservicio independiente ..... ✅"
else
    echo "   Microservicio independiente ..... ❌"
end
if test -n "$CONSUMIDO"
    echo "   Consumer procesa evento ......... ✅"
else
    echo "   Consumer procesa evento ......... ❌"
end
if test "$AFTER_LAG" = "0"
    echo "   Consumer Group sin atraso ....... lag 0 ✅"
else
    echo "   Consumer Group sin atraso ....... lag $AFTER_LAG ❌"
end

echo
echo "=========================================================="
if test $PASS -eq 1
    echo "✅ KAFKA FUNCIONAL ENTRE MICROSERVICIOS"
    echo "   3 brokers + 3 particiones + RF=3 + producer/consumer + lag 0"
else
    echo "⚠ REVISAR RESULTADOS ANTES DE GUARDAR EVIDENCIA"
end
echo "=========================================================="

rm -f "$TMP_RETIRO"
functions -e obtener_offsets
functions -e describir_topic
functions -e health_container

if test $PASS -eq 1
    exit 0
else
    exit 1
end
