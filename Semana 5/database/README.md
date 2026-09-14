# Base de datos reproducible — Semana 5

Esta carpeta permite levantar una base PostgreSQL limpia sin depender del volumen local de desarrollo.

## Archivos

- `01_schema.sql`: crea las cuatro tablas de negocio consumidas por `bank-backend`.
- `02_seed_processed_snapshot.sql`: carga un snapshot reproducible derivado de los tres CSV legacy incluidos en `../data/legacy/`.

El snapshot contiene:

- 50 cuentas procesadas.
- 20 estados de cuenta anuales agregados.
- 482 transacciones válidas/corregidas.
- 265 resúmenes diarios.

Las cuentas `101` a `108` y el estado anual `101/2024` se mantienen alineados con la evidencia funcional validada durante la Semana 5, de modo que los scripts de verificación produzcan resultados reproducibles.

## Inicialización

En un entorno limpio basta con ejecutar desde la raíz:

```fish
docker compose up -d
```

PostgreSQL ejecuta los scripts de `docker-entrypoint-initdb.d` solamente cuando crea un volumen nuevo. Para reinicializar desde cero:

```fish
docker compose down -v
docker compose up -d
```

> `down -v` elimina el volumen local de PostgreSQL. Úsalo solo cuando quieras reconstruir la base desde los scripts incluidos.
