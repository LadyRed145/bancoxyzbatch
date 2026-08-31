#!/usr/bin/env fish

set JAR "target/bancoxyzbatch-0.0.1-SNAPSHOT.jar"
set BENCH_DB "bancoxyz_bench"
set DB_URL_BENCH "jdbc:postgresql://localhost:5432/$BENCH_DB"
set RESULT_DIR "benchmarks"
set CSV_FILE "$RESULT_DIR/chunks.csv"

mkdir -p "$RESULT_DIR"

echo "threads,chunk_size,repeticion,duracion_ms" > "$CSV_FILE"

function reset_benchmark_database

    echo
    echo "=================================================="
    echo "[BENCH] Reiniciando base de datos $BENCH_DB"
    echo "=================================================="

    docker compose exec -T postgres \
        psql -U bancoxyz -d postgres \
        -c "DROP DATABASE IF EXISTS $BENCH_DB WITH (FORCE);" \
        >/dev/null

    if test $status -ne 0
        echo "[ERROR] No se pudo eliminar $BENCH_DB"
        exit 1
    end

    docker compose exec -T postgres \
        psql -U bancoxyz -d postgres \
        -c "CREATE DATABASE $BENCH_DB OWNER bancoxyz;" \
        >/dev/null

    if test $status -ne 0
        echo "[ERROR] No se pudo crear $BENCH_DB"
        exit 1
    end
end


if not test -f "$JAR"
    echo "[ERROR] No existe $JAR"
    echo "Ejecuta primero:"
    echo "./mvnw clean package -DskipTests"
    exit 1
end


set run_id 4000

for chunk_size in 5 10 25 50

    for repeticion in 1 2 3

        set run_id (math $run_id + 1)

        reset_benchmark_database

        set LOG_FILE \
            "$RESULT_DIR/chunks_c"$chunk_size"_r"$repeticion".log"

        echo
        echo "=================================================="
        echo "[BENCH]"
        echo "threads     = 3"
        echo "chunkSize   = $chunk_size"
        echo "repeticion  = $repeticion"
        echo "run.id      = $run_id"
        echo "=================================================="

        env DB_URL="$DB_URL_BENCH" \
            java -jar "$JAR" \
            --app.batch.job=transaccionJob \
            --app.batch.run-id="$run_id" \
            --app.batch.threads=3 \
            --app.batch.chunk-size="$chunk_size" \
            > "$LOG_FILE" 2>&1

        if not grep -q \
            '\[BATCH\] Estado final: COMPLETED' \
            "$LOG_FILE"

            echo
            echo "[ERROR] La ejecución no terminó en COMPLETED."
            echo "Revisa:"
            echo "$LOG_FILE"
            exit 1
        end

        set PERF_LINE \
            (grep \
                '\[BATCH-PERF\] job=transaccionJob' \
                "$LOG_FILE" \
                | tail -n 1)

        set DURACION \
            (echo "$PERF_LINE" \
                | sed -E \
                's/.*duraciónMs=([0-9.]+).*/\1/')

        echo \
            "3,$chunk_size,$repeticion,$DURACION" \
            >> "$CSV_FILE"

        echo "[OK] duraciónMs=$DURACION"
    end
end


echo
echo "=================================================="
echo "BENCHMARK DE CHUNKS TERMINADO"
echo "=================================================="
echo

cat "$CSV_FILE"

echo
echo "Resultados guardados en:"
echo "$CSV_FILE"
echo
