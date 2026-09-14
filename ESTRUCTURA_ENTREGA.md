# Estructura de entrega limpia — Semana 5

Esta copia se prepara específicamente para la actividad sumativa de Semana 5.

## Se excluye

- `.git/` del ZIP de entrega.
- directorios `target/`.
- semanas 1 a 4.
- documentación antigua de Semana 4.
- archivos de editor dentro del código fuente.
- variables locales `.env`.

## Se incluye y ordena

- tres CSV legacy completos;
- esquema y snapshot SQL reproducibles;
- `docker-compose.yml` con inicialización automática de PostgreSQL;
- `.env.example`;
- README y propuesta técnica actualizados;
- certificados académicos de los tres BFF;
- scripts de verificación;
- carpeta `docs/` reservada para la evidencia manual de Semana 5.

## Organización técnica de cada BFF

La implementación queda alineada con los temas trabajados en clases:

```text
controller -> service -> client -> Bank Backend
                   \
                    -> mapper -> dto

exception -> 400/404/409 + 503/504
config    -> WebClient + seguridad + HTTPS
```

- `client`: desacopla la comunicación HTTP del caso de uso.
- `mapper`: transforma contratos únicamente donde existe reducción real de datos.
- `backend.timeout`: evita esperas indefinidas.
- `503`: representa indisponibilidad de la dependencia.
- `504`: representa timeout de la dependencia.
