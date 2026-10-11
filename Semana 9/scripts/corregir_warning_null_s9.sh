#!/usr/bin/env bash
# BancoXYZ S9: elimina el warning JDT de referencia a metodo en test, sin cambios funcionales.
set -euo pipefail

ROOT="${BANCOXYZ_ROOT:-$PWD}"
TEST_FILE="$ROOT/Semana 9/bank-backend/src/test/java/cl/duoc/bancoxyz/backend/service/CuentaInteresServiceTest.java"
POM="$ROOT/Semana 9/bank-backend/pom.xml"

if [[ ! -f "$TEST_FILE" || ! -f "$POM" ]]; then
  printf 'ERROR: ejecuta desde la raiz bancoxyzbatch. No encuentro el test y/o su pom.xml.\n' >&2
  exit 2
fi

python3 - "$TEST_FILE" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
original = path.read_text(encoding='utf-8')
if 'void publicaSoloDespuesDeCommitConfirmado()' not in original:
    raise SystemExit('ERROR: no encontre el test esperado; archivo intacto.')

pattern = re.compile(
    r'(?m)^(?P<indent>[ \t]*)TransactionSynchronizationManager\.getSynchronizations\(\)[ \t]*\n'
    r'[ \t]*\.forEach\(TransactionSynchronization::afterCommit\);[ \t]*$'
)

def replace(match):
    indent = match.group('indent')
    return (
        indent + 'for (TransactionSynchronization synchronization : TransactionSynchronizationManager.getSynchronizations()) {\n'
        + indent + '    synchronization.afterCommit();\n'
        + indent + '}'
    )

updated, count = pattern.subn(replace, original)
if count == 1:
    path.write_text(updated, encoding='utf-8', newline='')
    print('APLICADO: referencia de metodo sustituida por for-each tipado en CuentaInteresServiceTest.java.')
elif count == 0 and re.search(r'for \(TransactionSynchronization synchronization : TransactionSynchronizationManager\.getSynchronizations\(\)\)\s*\{\s*synchronization\.afterCommit\(\);\s*\}', original):
    print('OK: la correccion ya estaba aplicada; sin cambios.')
else:
    raise SystemExit(f'ERROR: se encontraron {count} coincidencias; archivo intacto para evitar cambios equivocados.')
PY

printf '\n== Prueba focalizada del backend (sin PostgreSQL ni Kafka) ==\n'
mvn -f "$POM" -Dtest=CuentaInteresServiceTest test
printf '\nOK: correccion aplicada y CuentaInteresServiceTest aprobado.\n'
