#!/usr/bin/env fish
# BancoXYZ S9 - correccion segura y auditoria de riesgos conocidos.
# No elimina BD, no toca CSV, no modifica volumenes ni snapshots.
set -l root (pwd)
if not test -d "$root/Semana 9/scripts"
    echo 'ERROR: ejecuta desde la raiz bancoxyzbatch (debe existir Semana 9/scripts).'
    exit 2
end
set -l script "$root/Semana 9/scripts/verificar_entrega_completa.fish"
if not test -f "$script"
    echo 'ERROR: falta verificar_entrega_completa.fish; no se modifica nada.'
    exit 2
end
# Sustituye solamente el bloque destructivo conocido por una creacion condicional segura.
python3 - "$script" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); s = p.read_text()
old = '''    docker exec bancoxyz-postgres psql -U "$user" -d postgres -v ON_ERROR_STOP=1 \\
        -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$test_db' AND pid <> pg_backend_pid();" \\
        -c "DROP DATABASE IF EXISTS $test_db;" \\
        -c "CREATE DATABASE $test_db;" >/dev/null; or return 1'''
new = '''    # No destruir datos de ejecuciones anteriores. La BD de pruebas debe ser nueva.
    set -l db_existe (docker exec bancoxyz-postgres psql -U "$user" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$test_db'" 2>/dev/null)
    if test "$status" -ne 0
        echo "ERROR: no se pudo consultar PostgreSQL. No se toca la base de datos."
        return 1
    end
    if test "$db_existe" = 1
        echo "ERROR: la base de pruebas $test_db ya existe; se conserva intacta."
        echo "No se ejecuta el test destructivo. Usa una estrategia de pruebas no destructiva."
        return 1
    end
    docker exec bancoxyz-postgres psql -U "$user" -d postgres -v ON_ERROR_STOP=1 \\
        -c "CREATE DATABASE $test_db;" >/dev/null; or return 1'''
if old in s:
    p.write_text(s.replace(old,new,1))
    print('OK: eliminada la recreacion destructiva de la BD aislada.')
elif 'No destruir datos de ejecuciones anteriores.' in s:
    print('OK: proteccion de BD ya aplicada (idempotente).')
else:
    print('ERROR: bloque original distinto al auditado; no se modifico el archivo.')
    sys.exit(3)
PY
or exit $status
fish -n "$script"
or begin
    echo 'ERROR: sintaxis Fish invalida tras parche.'
    exit 4
end
printf '\n=== REVISION DE RIESGOS PENDIENTES (SIN CAMBIOS) ===\n'
set -l service "$root/Semana 9/bank-backend/src/main/java/cl/duoc/bancoxyz/backend/service/CuentaInteresService.java"
set -l producer "$root/Semana 9/bank-backend/src/main/java/cl/duoc/bancoxyz/backend/kafka/RetiroKafkaProducer.java"
set -l pagos "$root/Semana 9/pagos-service/src/main/java/cl/duoc/bancoxyz/pagos/PagosController.java"
if test -f "$service"; and grep -q 'retiroKafkaProducer.publicarRetiro(evento)' "$service"
    echo 'PENDIENTE: retiro y publicacion Kafka no son una transaccion atomica.'
end
if test -f "$producer"; and grep -q 'whenComplete' "$producer"
    echo 'PENDIENTE: fallo de publicacion Kafka se registra asincronamente; falta estrategia durable.'
end
if test -f "$pagos"; and grep -q 'NO modifica saldos' "$pagos"
    echo 'PENDIENTE: pagos-service registra solicitudes, pero no ejecuta operaciones monetarias.'
end
printf '\nOK: parche seguro aplicado. CSV, BD principal, snapshots y volumenes intactos.\n'
printf 'IMPORTANTE: no se han resuelto aun todos los hallazgos de la rubrica.\n'
