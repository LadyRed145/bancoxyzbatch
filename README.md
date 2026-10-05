# 🏦 BancoXYZ — Microservicios resilientes, seguros y orientados a eventos

> **Desarrollo Backend III (PBY2203) · Semana 8 · Entrega individual**
> **Autora: Natalia Alvarado**
> Spring Boot · Spring Cloud · OAuth2 · Keycloak · Resilience4j · Apache Kafka · PostgreSQL · Docker Compose · AWS EC2

---

## ✨ Resumen

BancoXYZ es una solución bancaria distribuida basada en microservicios. La **Semana 8** consolida la arquitectura construida en las entregas anteriores e integra los requerimientos finales de **seguridad OAuth2, resiliencia, mensajería asíncrona, contenerización, observabilidad y despliegue Cloud**.

La solución final está compuesta por **10 servicios orquestados mediante Docker Compose** y fue validada tanto en entorno local como en una instancia **AWS EC2**.

| Área | Estado final |
|---|---|
| Docker Compose | ✅ válido |
| Servicios | ✅ `10/10 healthy` |
| OAuth2 / Keycloak | ✅ `200 / 401 / 403` |
| Kafka entre microservicios | ✅ productor + consumidor + `lag 0` |
| Resilience4j | ✅ `CLOSED → OPEN → HALF_OPEN → CLOSED` |
| Acceso externo EC2 | ✅ Keycloak + BFF accesibles |
| Secretos | ✅ externalizados y fuera de Git |
| Evidencia | ✅ preparada en `Semana 8/docs/` |

### ✅ Criterio de rúbrica — OAuth2 / Keycloak (implementado)

El requisito de **OAuth2 no corresponde a una mejora futura**: está **implementado, integrado y validado** en la solución final. Los tres BFF funcionan como **Spring Resource Server JWT**, utilizan clientes y scopes independientes en Keycloak y fueron probados en AWS EC2 con los resultados esperados:

```text
bff-web-client     + bancoxyz.web     → HTTP 200
bff-mobile-client  + bancoxyz.mobile  → HTTP 200
bff-atm-client     + bancoxyz.atm     → HTTP 200

Sin token / token inválido             → HTTP 401
Token válido con scope incorrecto       → HTTP 403
```

La mejora futura mencionada en este documento se refiere únicamente al **endurecimiento productivo del transporte** —DNS, TLS válido, reverse proxy y `sslRequired`—, no a la implementación de OAuth2, que ya forma parte funcional de Semana 8.

---

## 🧭 Arquitectura final

```mermaid
flowchart TB
    EXT["🌐 Cliente externo"] --> KC["🔐 Keycloak<br/>host :8084"]
    EXT --> WEB["🖥️ BFF Web<br/>HTTPS :8081"]
    EXT --> MOB["📱 BFF Mobile<br/>HTTPS :8082"]
    EXT --> ATM["🏧 BFF ATM<br/>HTTPS :8083"]

    CFG["⚙️ Config Server<br/>:8888"] --> WEB
    CFG --> MOB
    CFG --> ATM

    EUREKA["🧭 Eureka Server<br/>:8761"] <--> WEB
    EUREKA <--> MOB
    EUREKA <--> ATM
    EUREKA <--> BACK["🏦 Bank Backend<br/>:8080"]
    EUREKA <--> CONSUMER["📨 Retiros Event Consumer<br/>:8090"]

    WEB --> BACK
    MOB --> BACK
    ATM --> BACK

    BACK --> DB["💾 PostgreSQL 17<br/>:5432"]
    BACK --> KAFKA["📬 Apache Kafka<br/>:29092 interno"]
    KAFKA --> CONSUMER

    KC -. JWT / scopes .-> WEB
    KC -. JWT / scopes .-> MOB
    KC -. JWT / scopes .-> ATM
```

### Flujo natural

```text
Cliente
  │
  ├── OAuth2 / Keycloak
  │
  ▼
BFF Web / Mobile / ATM
  │
  ├── Config Server
  ├── Eureka + LoadBalancer
  ├── Resilience4j
  │
  ▼
Bank Backend
  │
  ├── PostgreSQL
  │
  └── Kafka ──► Retiros Event Consumer
```

---

## 🧩 Servicios del stack

| # | Servicio | Responsabilidad principal | Exposición |
|---:|---|---|---|
| 1 | PostgreSQL 17 | Persistencia bancaria | `127.0.0.1:5432` |
| 2 | Apache Kafka | Transporte asíncrono de eventos | `127.0.0.1:9092` / `kafka:29092` |
| 3 | Keycloak 26.8.0 | OAuth2 y emisión de JWT | `0.0.0.0:8084` |
| 4 | Config Server | Configuración centralizada | `127.0.0.1:8888` |
| 5 | Eureka Discovery Server | Registro y descubrimiento | `127.0.0.1:8761` |
| 6 | Bank Backend | Lógica bancaria, persistencia y productor Kafka | `127.0.0.1:8080` |
| 7 | BFF Web | Contrato Web | `0.0.0.0:8081` |
| 8 | BFF Mobile | Contrato Mobile | `0.0.0.0:8082` |
| 9 | BFF ATM | Contrato ATM | `0.0.0.0:8083` |
| 10 | Retiros Event Consumer | Consumo independiente de retiros | sólo red Docker `:8090` |

Los servicios internos se comunican mediante la red `bancoxyz-net`. La infraestructura sensible permanece ligada a loopback o exclusivamente a la red Docker.

---

## 🔐 Seguridad con OAuth2 y Keycloak

BancoXYZ utiliza **OAuth2.0 Client Credentials** mediante Keycloak.

### Realm

```text
bancoxyz
```

### Clientes

```text
bff-web-client
bff-mobile-client
bff-atm-client
```

### Scopes

```text
bancoxyz.web
bancoxyz.mobile
bancoxyz.atm
```

Cada BFF funciona como **Spring Resource Server JWT** y exige el scope correspondiente a su canal.

### Comportamiento validado

```text
Token correcto + scope correcto  → HTTP 200
Sin token / token inválido       → HTTP 401
Token válido + scope incorrecto  → HTTP 403
```

La validación en EC2 confirmó los tres clientes y los tres escenarios de seguridad.

---

## 🔄 Rutas OAuth2 en Cloud

En AWS se separan explícitamente dos conceptos:

```text
Issuer público del JWT
    └── http://<ELASTIC_IP>:8084/realms/bancoxyz

Obtención local de token para scripts ejecutados dentro de EC2
    └── http://127.0.0.1:8084/realms/bancoxyz/protocol/openid-connect/token
```

Variables relevantes:

```text
KEYCLOAK_PUBLIC_URL
OAUTH2_ISSUER_URI
OAUTH2_TOKEN_URL
```

Esta separación evita que los scripts de la propia instancia intenten volver a entrar por la Elastic IP cuando el Security Group está restringido.

### SSL del realm en laboratorio

Para el despliegue académico se utiliza:

```json
"sslRequired": "none"
```

Esto permite validar Keycloak mediante HTTP sobre la Elastic IP en un entorno de laboratorio.

> ⚠️ **Producción:** `sslRequired: none` no debe utilizarse como configuración final. Un entorno productivo debe utilizar DNS, TLS válido y HTTPS real delante de Keycloak.

---

## 🔑 Variables de entorno y secretos

El archivo real `.env` está excluido de Git. Los valores sensibles se generan o suministran externamente.

Variables principales:

```text
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
DB_URL

KEYCLOAK_ADMIN_USERNAME
KEYCLOAK_ADMIN_PASSWORD
KEYCLOAK_PUBLIC_URL

OAUTH2_ISSUER_URI
OAUTH2_TOKEN_URL
OAUTH2_WEB_CLIENT_SECRET
OAUTH2_MOBILE_CLIENT_SECRET
OAUTH2_ATM_CLIENT_SECRET

SSL_KEYSTORE_PASSWORD
```

Preparación:

```fish
cp .env.example .env
```

Permisos recomendados:

```bash
chmod 600 .env
```

> **Certificados académicos:** el repositorio incluye certificados PKCS12 (`.p12`) únicamente para reproducir HTTPS en el entorno de laboratorio. Estos certificados de práctica utilizan `SSL_KEYSTORE_PASSWORD=changeit`; por eso, después de copiar `.env.example` a `.env`, debe reemplazarse el placeholder `CHANGE_ME` por `changeit` para ejecutar los BFF incluidos. No son certificados ni credenciales de producción.
>
> **Buenas prácticas:** `.env`, claves privadas reales, contraseñas, client secrets y certificados de producción no deben versionarse. En un entorno real, los certificados deben emitirse y administrarse fuera del repositorio.

---

## 📨 Mensajería asíncrona con Kafka

El retiro bancario genera un evento sólo después de completar la operación principal.

```mermaid
sequenceDiagram
    participant ATM as BFF ATM
    participant BE as Bank Backend
    participant DB as PostgreSQL
    participant K as Kafka
    participant C as Retiros Event Consumer

    ATM->>BE: POST /retiro
    BE->>DB: validar cuenta y saldo
    BE->>DB: persistir nuevo saldo
    DB-->>BE: operación confirmada
    BE->>K: RetiroRealizadoEvent
    BE-->>ATM: HTTP 200
    K-->>C: bancoxyz.retiros
    C->>C: procesar evento
```

### Topic

```text
bancoxyz.retiros
```

### Consumer Group

```text
bancoxyz-retiros-group
```

### Evento

```text
RetiroRealizadoEvent
├── cuentaId
├── monto
├── saldoFinal
└── tipo = RETIRO
```

### Validación EC2

```text
Saldo antes .............. 5050.0
Retiro ................... HTTP 200
Saldo después ............ 5049.0
Producer ................. EVENTO PUBLICADO
Consumer ................. EVENTO CONSUMIDO
Offset ................... 0 → 1
Lag ...................... 0
```

El consumidor fue separado de `bank-backend` para demostrar mensajería real entre microservicios y permitir escalamiento independiente.

---

## 🛡️ Resiliencia con Resilience4j

Los BFF protegen la comunicación con `BANK-BACKEND` mediante:

- **Circuit Breaker**;
- **Retry** para operaciones seguras;
- **Rate Limiter**;
- **Timeout**;
- traducción controlada de errores.

El retiro ATM **no utiliza Retry automático**, porque no es una operación idempotente y un reintento podría provocar doble débito.

### Ciclo validado

```mermaid
stateDiagram-v2
    [*] --> CLOSED
    CLOSED --> OPEN: fallos repetidos
    OPEN --> HALF_OPEN: ventana de recuperación
    HALF_OPEN --> OPEN: probes fallidos
    HALF_OPEN --> CLOSED: probes exitosos
```

### Evidencia EC2

```text
Operación normal ........ HTTP 200
Fallo 1 ................. HTTP 504
Fallo 2 ................. HTTP 504
Circuit Breaker ......... OPEN
Rechazo rápido .......... HTTP 503
Eventos Retry ........... 6
Backend restaurado ...... healthy
Recuperación ............ HALF_OPEN
Circuit Breaker final ... CLOSED
```

Resultado:

```text
CLOSED → OPEN → HALF_OPEN → CLOSED
```

---

## ⚙️ Configuración centralizada y Service Discovery

### Config Server

Puerto:

```text
8888
```

Configuraciones principales:

```text
Semana 8/config-repo/
├── bff-web.properties
├── bff-mobile.properties
└── bff-atm.properties
```

Centraliza parámetros de Eureka, nombre lógico del backend, timeouts, Circuit Breaker, Retry, Rate Limiter y Actuator.

### Eureka

Puerto:

```text
8761
```

Los BFF resuelven el backend mediante:

```text
BANK-BACKEND
```

con Spring Cloud LoadBalancer, evitando depender de direcciones IP rígidas.

---

## 🌐 Backend for Frontend

### Web — `HTTPS :8081`

```text
GET /api/web/cuentas
GET /api/web/cuentas/{id}
GET /api/web/cuentas/{id}/detalle
```

### Mobile — `HTTPS :8082`

```text
GET /api/mobile/cuentas
GET /api/mobile/cuentas/{id}/resumen
```

### ATM — `HTTPS :8083`

```text
GET  /api/atm/cuentas/{id}/saldo
POST /api/atm/cuentas/{id}/retiro
```

Los BFF utilizan certificados PKCS12 académicos y exigen `SSL_KEYSTORE_PASSWORD` mediante variable de entorno.

---

## 💾 Persistencia

PostgreSQL 17 mantiene el estado bancario.

Archivos:

```text
Semana 8/database/
```

Hostname interno:

```text
postgres:5432
```

El volumen persistente conserva los datos con:

```fish
docker compose down
```

Para reinicializar completamente:

```fish
docker compose down -v
```

> Usar `-v` sólo cuando se quiera eliminar deliberadamente la persistencia.

---

## 🔎 Observabilidad

Los servicios utilizan Spring Boot Actuator.

Endpoints relevantes:

```text
/actuator/health
/actuator/info
/actuator/circuitbreakers
/actuator/circuitbreakerevents
/actuator/retries
/actuator/retryevents
/actuator/ratelimiters
/actuator/ratelimiterevents
```

Los healthchecks de Docker Compose controlan el orden de arranque de las dependencias.

---

## 📁 Estructura del proyecto

```text
bancoxyzbatch/
├── .env.example
├── .gitignore
├── docker-compose.yml
├── mvnw
├── mvnw.cmd
├── pom.xml
├── README.md
├── Propuesta_Tecnica.md
└── Semana 8/
    ├── bank-backend/
    ├── bff/
    │   ├── bff-atm/
    │   ├── bff-mobile/
    │   └── bff-web/
    ├── config-repo/
    ├── config-server/
    ├── data/
    │   └── legacy/
    ├── database/
    ├── discovery-server/
    ├── docs/
    │   └── Documentacion_Capturas.pdf
    ├── keycloak/
    ├── retiros-event-consumer/
    └── scripts/
```

No se versionan:

```text
.env
*.pem
target/
backups operacionales
archivos temporales
```

---

## 🧱 Build Maven

Compilación:

```fish
./mvnw clean compile -DskipTests
```

Empaquetado:

```fish
./mvnw clean package -DskipTests
```

El `pom.xml` raíz agrega los módulos Java de la solución, incluido `retiros-event-consumer`.

---

## 🐳 Ejecución local con Docker Compose

Validar:

```fish
docker compose config
```

Levantar:

```fish
docker compose up --build -d
```

Estado:

```fish
docker compose ps
```

Detener sin eliminar datos:

```fish
docker compose down
```

La validación local final alcanzó:

```text
10/10 servicios healthy
OAuth2 3/3 clientes funcionales
Kafka productor + consumidor + lag 0
Resilience4j fallo + recuperación verificados
```

---

## ☁️ Despliegue validado en AWS EC2

La solución fue desplegada y comprobada funcionalmente sobre AWS.

### Entorno utilizado

```text
AWS EC2
Ubuntu Server 26.04.1 LTS x86_64
t3.large
2 vCPU
8 GiB RAM
50 GiB gp3
Elastic IP
Docker Engine
Docker Compose Plugin
```

### Security Group

Acceso exterior controlado:

```text
22    SSH
8081  BFF Web
8082  BFF Mobile
8083  BFF ATM
8084  Keycloak
```

Infraestructura no publicada a Internet:

```text
8080  Bank Backend
8888  Config Server
8761  Eureka
9092  Kafka
5432  PostgreSQL
8090  Retiros Event Consumer
```

### Clonado

```bash
git clone --filter=blob:none --no-checkout \
  https://github.com/LadyRed145/bancoxyzbatch.git \
  bancoxyzbatch

cd bancoxyzbatch

git sparse-checkout init --cone
git sparse-checkout set "Semana 8"
git checkout main
```

### Variables Cloud

```text
KEYCLOAK_PUBLIC_URL=http://<ELASTIC_IP>:8084
OAUTH2_ISSUER_URI=http://<ELASTIC_IP>:8084/realms/bancoxyz
OAUTH2_TOKEN_URL=http://127.0.0.1:8084/realms/bancoxyz/protocol/openid-connect/token
```

### Inicio

```bash
docker compose config >/dev/null
docker compose up --build -d
docker compose ps
```

> **Nota operativa:** el primer arranque de Keycloak puede tardar más debido a la inicialización e importación del realm. Una vez `healthy`, los BFF pueden iniciarse nuevamente sin reconstruir imágenes.

---

## 🌍 Validación externa desde un equipo distinto a EC2

Desde el notebook local se comprobó el acceso atravesando:

```text
Notebook
   ↓
Internet
   ↓
Security Group
   ↓
Elastic IP
   ↓
EC2
   ↓
Docker
   ↓
Keycloak / BFF
```

Resultados:

```text
Keycloak OIDC .............. HTTP 200
BFF Web health ............. HTTP 200
BFF Mobile health .......... HTTP 200
BFF ATM health ............. HTTP 200

WEB sin token .............. HTTP 401
MOBILE sin token ........... HTTP 401
ATM sin token .............. HTTP 401
```

Esto demuestra que los servicios públicos responden desde fuera de la instancia y que los endpoints protegidos continúan rechazando solicitudes no autenticadas.

---

## 🧰 Scripts de validación

Ubicación:

```text
Semana 8/scripts/
```

Principales scripts:

```fish
fish "Semana 8/scripts/verificar_bff.fish"
fish "Semana 8/scripts/verificar_oauth2.fish"
fish "Semana 8/scripts/verificar_actuator_resilience.fish"
fish "Semana 8/scripts/verificar_resilience4j_fallo_recuperacion.fish"
fish "Semana 8/scripts/verificar_kafka_microservicios.fish"
fish "Semana 8/scripts/auditar_kafka_huerfanos.fish"
```

Helper OAuth2:

```fish
fish "Semana 8/scripts/oauth2_obtener_token.fish" web
fish "Semana 8/scripts/oauth2_obtener_token.fish" mobile
fish "Semana 8/scripts/oauth2_obtener_token.fish" atm
```

Buenas prácticas incorporadas al cierre Cloud:

- resolución dinámica de `PROJECT_ROOT`;
- ausencia de rutas absolutas de usuario;
- timeouts de red para evitar bloqueos indefinidos;
- separación entre issuer público y token endpoint local;
- scripts reutilizables tanto en local como en EC2.

---

## ✅ Validación final

| Validación | Local | AWS EC2 |
|---|:---:|:---:|
| Docker Compose válido | ✅ | ✅ |
| `10/10` servicios healthy | ✅ | ✅ |
| BFF Web / Mobile / ATM | ✅ | ✅ |
| OAuth2 credenciales válidas `200` | ✅ | ✅ |
| OAuth2 sin token / inválido `401` | ✅ | ✅ |
| OAuth2 scope incorrecto `403` | ✅ | ✅ |
| Circuit Breaker | ✅ | ✅ |
| Retry | ✅ | ✅ |
| Rate Limiter | ✅ | ✅ |
| `CLOSED → OPEN → HALF_OPEN → CLOSED` | ✅ | ✅ |
| Kafka Producer | ✅ | ✅ |
| Kafka Consumer independiente | ✅ | ✅ |
| Consumer Group `lag 0` | ✅ | ✅ |
| Secretos fuera del código | ✅ | ✅ |
| `.env` fuera de Git | ✅ | ✅ |
| Acceso externo por Elastic IP | — | ✅ |

---

## 📸 Evidencia de despliegue Cloud

La documentación final se concentra en:

```text
Semana 8/docs/Documentacion_Capturas.pdf
```

Capturas principales:

```text
08_BANCOXYZ - HEALTHCHECK FINAL_EC2.png
09_PRUEBA_OAUT2_EC2_FINALIZADA.png
10_KAFKA_ENTRE_MICROSERVICIOS_EC2.png
11A_RESILIENCE4J_EC2_FINALIZADA.png
11B_RESILIENCE4J_EC2_FINALIZADA.png
12B_ACCESO_EXTERNO_ELASTIC_IP_EC2.png
```

Las evidencias cubren salud del stack, OAuth2, Kafka entre microservicios, Resilience4j y acceso externo desde Internet.

---

## 🧹 Buenas prácticas aplicadas

- separación clara de responsabilidades;
- BFF por canal consumidor;
- configuración centralizada;
- Service Discovery;
- mensajería asíncrona desacoplada;
- consumer Kafka independiente;
- healthchecks y dependencias controladas;
- secretos externalizados;
- `.env` fuera del repositorio;
- puertos internos ligados a loopback;
- scripts reproducibles;
- rutas portables entre local y Cloud;
- backups fuera del repositorio;
- evidencia técnica organizada;
- checkpoints estables antes del despliegue.

---

## 🚀 Consideraciones de producción

El proyecto corresponde a un entorno académico. **OAuth2 + Keycloak ya están implementados y funcionales**; las siguientes medidas corresponden únicamente a su endurecimiento para un entorno productivo:

- DNS propio;
- reverse proxy;
- TLS público válido;
- restaurar `sslRequired` para exigir HTTPS externo en Keycloak;
- gestión centralizada de secretos;
- CI/CD;
- monitoreo y alertas;
- Kafka con alta disponibilidad;
- PostgreSQL administrado o replicado;
- backups automáticos;
- rotación de credenciales;
- reglas de red aún más restrictivas.

---

## 🎯 Resultado

BancoXYZ Semana 8 finaliza como una arquitectura distribuida con **OAuth2 funcional, resiliencia verificable, mensajería asíncrona entre microservicios, persistencia, observabilidad, contenerización y despliegue Cloud real**.

La solución fue validada de extremo a extremo:

```text
Seguridad
   +
Resiliencia
   +
Persistencia
   +
Mensajería
   +
Docker
   +
AWS EC2
   =
BancoXYZ Semana 8 ✅
```

---

**BancoXYZ · Natalia Alvarado · Desarrollo Backend III (PBY2203) · Semana 8**
