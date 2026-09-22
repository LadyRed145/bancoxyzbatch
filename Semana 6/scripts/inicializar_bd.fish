#!/usr/bin/env fish

# Levanto PostgreSQL con el esquema y snapshot incluidos en la entrega.
# Si el volumen ya existe, Docker conserva sus datos y no vuelve a ejecutar los scripts de init.

set ROOT (cd (dirname (status --current-filename))/../..; and pwd)
cd "$ROOT"; or exit 1

docker compose up -d

echo 'Esperando PostgreSQL...'
for intento in (seq 1 30)
    if docker exec bancoxyz-postgres pg_isready -U bancoxyz -d bancoxyz >/dev/null 2>&1
        echo 'PostgreSQL listo.'
        docker exec bancoxyz-postgres psql -U bancoxyz -d bancoxyz -c '\dt'
        exit 0
    end
    sleep 1
end

echo 'ERROR: PostgreSQL no quedó disponible dentro del tiempo esperado.'
exit 1
