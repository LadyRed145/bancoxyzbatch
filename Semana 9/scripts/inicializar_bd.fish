#!/usr/bin/env fish

# Levanta únicamente PostgreSQL con su esquema inicial. No carga snapshots antiguos.
# Si el volumen ya existe, Docker conserva sus datos y no vuelve a ejecutar los scripts de init.

set ROOT (cd (dirname (status --current-filename))/../..; and pwd)
cd "$ROOT"; or exit 1

function dotenv_get --argument-names name
    awk -F= -v key="$name" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$ROOT/.env"
end

set DB_USER (dotenv_get POSTGRES_USER)
set DB_NAME (dotenv_get POSTGRES_DB)
test -n "$DB_USER"; or set DB_USER bancoxyz
test -n "$DB_NAME"; or set DB_NAME bancoxyz

# Este helper no debe arrancar los 16 servicios: su responsabilidad es sólo la base de datos.
docker compose up -d postgres

if test $status -ne 0
    echo 'ERROR: no fue posible iniciar PostgreSQL.'
    exit 1
end

echo 'Esperando PostgreSQL...'
for intento in (seq 1 30)
    if docker exec bancoxyz-postgres pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1
        echo 'PostgreSQL listo.'
        docker exec bancoxyz-postgres psql -U "$DB_USER" -d "$DB_NAME" -c '\dt'
        exit 0
    end
    sleep 1
end

echo 'ERROR: PostgreSQL no quedó disponible dentro del tiempo esperado.'
exit 1
