# BancoXYZ — Backend for Frontend (BFF) — Semana 5

Actividad sumativa de **Desarrollo Backend III (PBY2203)**.

La solución implementa tres **Backend for Frontend independientes** para Web, Mobile y ATM sobre un Bank Backend común. Cada canal adapta sus endpoints y payloads, restringe sus permisos, utiliza HTTPS y mantiene desacoplada la comunicación con los servicios internos.

## Arquitectura

```text
Web Client    -> BFF Web    (HTTPS 8081 / ROLE_WEB)    \
Mobile Client -> BFF Mobile (HTTPS 8082 / ROLE_MOBILE) ---> Bank Backend (HTTP 8080) ---> PostgreSQL 17
ATM Client    -> BFF ATM    (HTTPS 8083 / ROLE_ATM)    /
```

Los BFF consumen el Bank Backend mediante una capa `client` basada en `WebClient`. Ningún BFF accede directamente a PostgreSQL, repositorios JPA ni entidades de persistencia del backend.

## Organización interna de los BFF

La estructura se alinea con la separación de responsabilidades trabajada en la semana:

```text
controller  -> expone endpoints del canal
service     -> coordina el caso de uso
client      -> encapsula llamadas HTTP al Bank Backend
mapper      -> transforma respuestas del backend al contrato del canal
dto         -> define contratos de entrada/salida
exception   -> traduce errores funcionales, indisponibilidad y timeout
config      -> seguridad y WebClient
```

En Web no agrego un `mapper` artificial porque el canal conserva una respuesta rica en `JsonNode`; la transformación relevante allí es la agregación concurrente del detalle. Mobile y ATM sí cuentan con mappers explícitos porque reducen el contrato recibido desde el backend.

## Estructura de entrega

```text
bancoxyzbatch/
├── README.md
├── Propuesta_Tecnica.md
├── ESTRUCTURA_ENTREGA.md
├── docker-compose.yml
├── .env.example
├── .gitignore
├── pom.xml
├── mvnw
├── .mvn/
└── Semana 5/
    ├── bank-backend/
    ├── bff/
    │   ├── bff-web/
    │   ├── bff-mobile/
    │   └── bff-atm/
    ├── data/legacy/
    │   ├── intereses.csv
    │   ├── cuentas_anuales.csv
    │   └── transacciones.csv
    ├── database/
    │   ├── 01_schema.sql
    │   ├── 02_seed_processed_snapshot.sql
    │   └── README.md
    ├── docs/
    └── scripts/
        ├── inicializar_bd.fish
        ├── verificar_bff.fish
        └── verificar_retiro_controlado.fish
```

## Datos incluidos

La entrega contiene los **tres CSV legacy completos (1000 filas cada uno)** y una base reproducible derivada de ellos:

- 50 cuentas procesadas.
- 20 estados de cuenta anuales.
- 482 transacciones procesadas válidas/corregidas.
- 265 resúmenes diarios.

Las cuentas 101–108 se mantienen alineadas con la evidencia funcional validada de Semana 5.

## Requisitos

- Java 21
- Docker + Docker Compose
- Fish shell (solo para scripts de verificación)
- `curl`, `jq` y `openssl` para las pruebas automáticas

## 1. Levantar PostgreSQL

Desde la raíz:

```fish
docker compose up -d
```

En un volumen nuevo se ejecutan automáticamente `01_schema.sql` y `02_seed_processed_snapshot.sql`.

Para comprobarlo:

```fish
docker exec bancoxyz-postgres psql -U bancoxyz -d bancoxyz -c '\dt'
```

> Para reconstruir la BD desde cero: `docker compose down -v` y luego `docker compose up -d`. Esto elimina el volumen local actual.

## 2. Compilar todos los módulos

```fish
./mvnw clean compile
```

El POM raíz compila:

- `bank-backend`
- `bff-web`
- `bff-mobile`
- `bff-atm`

## 3. Ejecutar servicios

Abrir cuatro terminales.

### Bank Backend
```fish
cd "Semana 5/bank-backend"
./mvnw spring-boot:run
```

### BFF Web
```fish
cd "Semana 5/bff/bff-web"
./mvnw spring-boot:run
```

### BFF Mobile
```fish
cd "Semana 5/bff/bff-mobile"
./mvnw spring-boot:run
```

### BFF ATM
```fish
cd "Semana 5/bff/bff-atm"
./mvnw spring-boot:run
```

## BFF por canal

| Canal | URL | Rol | Objetivo |
|---|---|---|---|
| Web | `https://localhost:8081` | `ROLE_WEB` | Datos completos y agregación |
| Mobile | `https://localhost:8082` | `ROLE_MOBILE` | Payload reducido |
| ATM | `https://localhost:8083` | `ROLE_ATM` | Saldo y retiro con respuesta mínima |

### Endpoints personalizados

```text
WEB
GET /api/web/cuentas
GET /api/web/cuentas/{id}
GET /api/web/cuentas/{id}/detalle

MOBILE
GET /api/mobile/cuentas
GET /api/mobile/cuentas/{id}/resumen

ATM
GET  /api/atm/cuentas/{id}/saldo
POST /api/atm/cuentas/{id}/retiro
```

### Métricas validadas

| Operación | Tamaño observado |
|---|---:|
| Web — cuentas completas | 2174 B |
| Web — detalle agregado | 449 B |
| Mobile — cuentas resumidas | 784 B |
| Mobile — resumen individual | 93 B |
| ATM — saldo | 61 B |
| ATM — retiro controlado | 65 B |

## Resiliencia y servicios no disponibles

Todos los BFF definen un timeout configurable para las llamadas al Bank Backend:

```properties
backend.timeout=${BACKEND_TIMEOUT:3s}
```

La capa `client` aplica ese límite antes de devolver control al `service`.

Comportamiento previsto:

```text
El backend responde con error funcional -> se conserva su status (400/404/409, etc.)
El backend no acepta conexión          -> 503 Service Unavailable
El backend excede el timeout           -> 504 Gateway Timeout
```

Así evito que una dependencia lenta o caída deje solicitudes esperando indefinidamente y mantengo los detalles HTTP fuera de la lógica de negocio del BFF.

## Seguridad

Los tres BFF utilizan HTTPS con certificados PKCS12 académicos y Bearer Tokens asociados a roles.

Comportamiento validado:

```text
Sin token                  -> 401
Token desconocido          -> 401
WEB -> BFF Mobile          -> 403
MOBILE -> BFF ATM          -> 403
ATM -> BFF Web             -> 403
```

Los valores incluidos son exclusivamente académicos. En producción se recomienda OAuth2/OIDC, JWT de corta duración, gestión externa de secretos y certificados emitidos por una CA.

## Verificación automática

Con los cuatro servicios activos:

```fish
fish "Semana 5/scripts/verificar_bff.fish"
```

Resultado esperado:

```text
VERIFICACIÓN FINAL: TODAS LAS PRUEBAS PASARON
```

Para demostrar un retiro real sin alterar las cuentas originales:

```fish
fish "Semana 5/scripts/verificar_retiro_controlado.fish"
```

El script crea una cuenta temporal, retira `$1.00`, comprueba el saldo y elimina el fixture. Resultado esperado:

```text
VERIFICACIÓN DE RETIRO: OK
Retiro real validado sin alterar la cuenta original.
```

## Evidencias

La documentación final de capturas debe guardarse en:

```text
Semana 5/docs/BancoXYZ_BFF_Evidencias_Semana5.pdf
```

## Buenas prácticas aplicadas

- BFF independientes por canal.
- Endpoints personalizados según consumidor.
- Separación `controller -> service -> client`.
- Mappers explícitos donde existe transformación real de contrato.
- DTOs específicos y payloads mínimos.
- BFF desacoplados de persistencia y entidades JPA.
- Timeout configurable en la integración HTTP.
- `503 Service Unavailable` ante indisponibilidad del backend.
- `504 Gateway Timeout` ante respuesta demasiado lenta.
- Autenticación y autorización por rol.
- HTTPS en los tres BFF.
- Sesiones stateless.
- Validación de entradas.
- Manejo semántico de errores.
- Compresión de respuestas JSON.
- Maven multi-módulo.
- Datos legacy incluidos.
- PostgreSQL reproducible mediante Docker Compose.
- Pruebas automáticas sin alterar los datos originales.

## Evolución productiva

Para un entorno real agregaría, sin sobrecargar esta entrega académica:

- OAuth2 / OpenID Connect y JWT firmados de corta duración.
- Gestión externa de secretos.
- Certificados emitidos por una CA y TLS interno.
- Circuit breaker y retry únicamente donde sea seguro e idempotente.
- Rate limiting.
- Métricas, trazabilidad y alertas.
- Testcontainers y pipeline CI/CD.
