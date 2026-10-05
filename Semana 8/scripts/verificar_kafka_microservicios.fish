#!/usr/bin/env fish

# BancoXYZ - Semana 8
# Evidencia compacta/mediana de Kafka entre microservicios.
# Bank Backend publica el evento y retiros-event-consumer lo consume.

set -l ROOT (dirname (dirname (dirname (status --current-filename))))
cd "$ROOT"; or exit 1

set -l CONSUMER "bancoxyz-retiros-event-consumer"
set -l GROUP "bancoxyz-retiros-group"
set -l TOPIC "bancoxyz.retiros"
set -l TMP_RETIRO (mktemp /tmp/bancoxyz_kafka_retiro_XXXXXX)

function obtener_offsets --argument-names group topic
    docker exec bancoxyz-kafka \
        /opt/kafka/bin/kafka-consumer-groups.sh \
        --bootstrap-server localhost:9092 \
        --describe \
        --group "$group" 2>/dev/null \
        | awk -v topic="$topic" '$2 == topic {print $4 " " $5 " " $6; exit}'
end

function health_container --argument-names container
    docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null
end

echo "=========================================================="
echo " BANCOXYZ - EVIDENCIA KAFKA ENTRE MICROSERVICIOS"
echo "=========================================================="

echo
echo "1. ARQUITECTURA"
echo "   BFF ATM -> Bank Backend -> Kafka -> Retiros Consumer"
echo "   Topic ................. $TOPIC"
echo "   Consumer Group ........ $GROUP"

set -l KAFKA_H (health_container bancoxyz-kafka)
set -l BACKEND_H (health_container bancoxyz-bank-backend)
set -l CONSUMER_H (health_container "$CONSUMER")

echo
echo "2. ESTADO DE COMPONENTES"
echo "   Kafka ................. $KAFKA_H"
echo "   Bank Backend .......... $BACKEND_H  [PRODUCER]"
echo "   Retiros Consumer ...... $CONSUMER_H  [CONSUMER]"

set -l BEFORE (obtener_offsets "$GROUP" "$TOPIC")
set -l B (string split -- ' ' "$BEFORE")

# Un consumer group nuevo puede reportar "-" antes del primer commit.
# Para las comparaciones internas se normaliza a cero.
if test "$B[1]" = "-"
    set B[1] 0
end
if test "$B[3]" = "-"
    set B[3] 0
end
set -l BEFORE_CURRENT $B[1]
set -l BEFORE_END $B[2]
set -l BEFORE_LAG $B[3]

echo
echo "3. CONSUMER GROUP - ANTES"
echo "   Current Offset ........ $BEFORE_CURRENT"
echo "   Log End Offset ........ $BEFORE_END"
echo "   Lag ................... $BEFORE_LAG"

set -l START_TS (date -u +%Y-%m-%dT%H:%M:%SZ)

fish "Semana 8/scripts/verificar_retiro_controlado.fish" >$TMP_RETIRO 2>&1
set -l RETIRO_STATUS $status

sleep 2

set -l AFTER (obtener_offsets "$GROUP" "$TOPIC")
set -l A (string split -- ' ' "$AFTER")
set -l AFTER_CURRENT $A[1]
set -l AFTER_END $A[2]
set -l AFTER_LAG $A[3]

set -l PUBLICADO (docker logs bancoxyz-bank-backend --since "$START_TS" 2>&1 \
    | grep -m1 'EVENTO KAFKA PUBLICADO CORRECTAMENTE')

set -l CONSUMIDO (docker logs "$CONSUMER" --since "$START_TS" 2>&1 \
    | grep -m1 'EVENTO_KAFKA_CONSUMIDO')

set -l SALDO_ANTES (grep -m1 'Saldo antes:' $TMP_RETIRO)
set -l RETIRO (grep -m1 '^Retiro:' $TMP_RETIRO)
set -l SALDO_DESPUES (grep -m1 'Saldo después:' $TMP_RETIRO)

echo
echo "4. OPERACIÓN BANCARIA REAL"
echo "   $SALDO_ANTES"
echo "   $RETIRO"
echo "   $SALDO_DESPUES"

echo
echo "5. MENSAJERÍA ASÍNCRONA"
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
echo "6. CONSUMER GROUP - DESPUÉS"
echo "   Current Offset ........ $AFTER_CURRENT"
echo "   Log End Offset ........ $AFTER_END"
echo "   Lag ................... $AFTER_LAG"
echo "   Avance ................. $BEFORE_CURRENT -> $AFTER_CURRENT"

set -l PASS 1

if test "$KAFKA_H" != "healthy"; set PASS 0; end
if test "$BACKEND_H" != "healthy"; set PASS 0; end
if test "$CONSUMER_H" != "healthy"; set PASS 0; end
if test $RETIRO_STATUS -ne 0; set PASS 0; end
if test -z "$PUBLICADO"; set PASS 0; end
if test -z "$CONSUMIDO"; set PASS 0; end
if test -z "$AFTER_CURRENT"; set PASS 0; end
if test -z "$AFTER_END"; set PASS 0; end
if test "$AFTER_LAG" != "0"; set PASS 0; end

if string match -qr '^[0-9]+$' -- "$BEFORE_CURRENT"; and string match -qr '^[0-9]+$' -- "$AFTER_CURRENT"
    if test $AFTER_CURRENT -le $BEFORE_CURRENT
        set PASS 0
    end
else
    set PASS 0
end

echo
echo "7. VALIDACIÓN"
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
echo "   Consumer Group sin atraso ....... lag $AFTER_LAG"

echo
echo "=========================================================="
if test $PASS -eq 1
    echo "✅ KAFKA FUNCIONAL ENTRE MICROSERVICIOS"
    echo "   Publicación + consumo + offset + lag 0 verificados"
else
    echo "⚠ REVISAR RESULTADOS ANTES DE GUARDAR EVIDENCIA"
end
echo "=========================================================="

rm -f $TMP_RETIRO
functions -e obtener_offsets
functions -e health_container

if test $PASS -eq 1
    exit 0
else
    exit 1
end
