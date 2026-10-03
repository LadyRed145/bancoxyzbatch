# 🏦 BancoXYZ — Microservicios resilientes y arquitectura orientada a eventos

> **Desarrollo Backend III (PBY2203) · Semana 7 · Grupo 13**  
> Spring Cloud, Service Discovery, BFF por canal, Resilience4j, Apache Kafka y PostgreSQL.

---

## ✨ Resumen

BancoXYZ continúa la evolución de la solución bancaria hacia una arquitectura distribuida. La Semana 7 conserva la base de microservicios de la semana anterior e incorpora **mensajería asíncrona con Apache Kafka** sobre el flujo de retiro, manteniendo los mecanismos de resiliencia implementados con **Resilience4j**.

La solución incluye:

- **Config Server** para configuración centralizada.
- **Eureka Discovery Server** para registro y descubrimiento.
- **Bank Backend** como servicio responsable de lógica bancaria y persistencia.
- **BFF Web, Mobile y ATM** con contratos diferenciados por canal.
- **PostgreSQL 17** para persistencia.
- **Resilience4j** con Circuit Breaker, Retry y Rate Limiter.
- **Apache Kafka** para publicar y consumir eventos de retiro.
- **Docker Compose** para orquestar todos los componentes.

---

## 🧭 Arquitectura

```text
                           +----------------------+
                           |    Config Server     |
                           |        :8888         |
                           +----------+-----------+
                                      |
            +-------------------------+-------------------------+
            |                         |                         |
     +------v------+           +------v------+           +------v------+
     |   BFF Web   |           | BFF Mobile  |           |   BFF ATM   |
     | HTTPS :8081 |           | HTTPS :8082 |           | HTTPS :8083 |
     +------+------+           +------+------+           +------+------+ 
            |                         |                         |
            +-------------------------+-------------------------+
                                      |
                              Eureka + LoadBalancer
                                      |
                             +--------v---------+
                             |   Bank Backend   |
                             |    HTTP :8080    |
                             +---+----------+---+
                                 |          |
                    +------------+          +----------------+
                    |                                        |
           +--------v---------+                    +---------v---------+
           |  PostgreSQL 17   |                    |   Apache Kafka    |
           |      :5432       |                    |  :29092 / :9092  |
           +------------------+                    +---------+---------+
                                                             |
                                                bancoxyz.retiros
                                                             |
                                                +------------v-----------+
                                                | RetiroKafkaConsumer    |
                                                +------------------------+

                           +----------------------+
                           |    Eureka Server     |
                           |        :8761         |
                           +----------------------+
```

---

## 📨 Flujo Kafka de retiro

Cuando el BFF-ATM solicita un retiro:

1. `BFF-ATM` envía la operación al `bank-backend`.
2. El backend valida la cuenta y el saldo.
3. PostgreSQL persiste el nuevo saldo.
4. Se crea un `RetiroRealizadoEvent`.
5. `RetiroKafkaProducer` publica el evento en `bancoxyz.retiros`.
6. `RetiroKafkaConsumer` consume el mensaje de forma asíncrona.

El evento transporta:

```text
cuentaId
monto
saldoFinal
tipo = RETIRO
```

Kafka usa `kafka:29092` dentro de la red Docker y `localhost:9092` desde el host.

---

## 🛡️ Resiliencia

Los BFF mantienen mecanismos de Resilience4j sobre la comunicación con `BANK-BACKEND`:

- **Circuit Breaker** para aislar fallos repetidos.
- **Retry** de hasta 3 intentos en operaciones seguras de lectura.
- **Rate Limiter** para limitar ráfagas de solicitudes.
- **Timeout** y traducción controlada de errores.
- El retiro ATM **no utiliza reintentos automáticos**, evitando duplicar una operación no idempotente.

Ante la indisponibilidad del backend, el BFF entrega una respuesta controlada `HTTP 503 Service Unavailable`.

---

## 🔐 Seguridad de la base Semana 7

La Semana 7 conserva la autenticación académica por Bearer Token y roles por canal:

```text
ROLE_WEB
ROLE_MOBILE
ROLE_ATM
```

Los BFF funcionan sobre HTTPS con certificados PKCS12 académicos. La evolución a OAuth2.0 corresponde a la Semana 8 y no se mezcla con esta base estable.

---

## 📁 Estructura

```text
bancoxyzbatch/
├── .mvn/
│   └── wrapper/
│       └── maven-wrapper.properties
├── .env.example
├── .gitignore
├── docker-compose.yml
├── mvnw
├── mvnw.cmd
├── pom.xml
├── README.md
├── Propuesta_Tecnica.md
└── Semana 7/
    ├── bank-backend/
    ├── bff/
    │   ├── bff-atm/
    │   ├── bff-mobile/
    │   └── bff-web/
    ├── config-repo/
    ├── config-server/
    ├── data/legacy/
    ├── database/
    ├── discovery-server/
    └── scripts/
```

Los artefactos `target/` no forman parte del repositorio y están excluidos mediante `.gitignore`.

---

## 🐳 Ejecución con Docker Compose

Desde la raíz:

```fish
cp .env.example .env

docker compose config
docker compose up --build -d
```

Estado de los contenedores:

```fish
docker compose ps
```

Logs principales:

```fish
docker compose logs -f bank-backend
docker compose logs -f kafka
```

Detener el entorno:

```fish
docker compose down
```

Para eliminar también el volumen de PostgreSQL:

```fish
docker compose down -v
```

---

## 🧱 Build Maven

El proyecto raíz agrega los seis módulos principales.

```fish
./mvnw clean compile -DskipTests
```

Empaquetado:

```fish
./mvnw clean package -DskipTests
```

---

## 🔌 Puertos

| Componente | Puerto |
|---|---:|
| PostgreSQL | 5432 |
| Kafka host | 9092 |
| Config Server | 8888 |
| Eureka | 8761 |
| Bank Backend | 8080 |
| BFF Web | 8081 |
| BFF Mobile | 8082 |
| BFF ATM | 8083 |

---

## 🧪 Endpoints principales

### Web — `https://localhost:8081`

```text
GET /api/web/cuentas
GET /api/web/cuentas/{id}
GET /api/web/cuentas/{id}/detalle
```

### Mobile — `https://localhost:8082`

```text
GET /api/mobile/cuentas
GET /api/mobile/cuentas/{id}/resumen
```

### ATM — `https://localhost:8083`

```text
GET  /api/atm/cuentas/{id}/saldo
POST /api/atm/cuentas/{id}/retiro
```

Ejemplo de retiro:

```fish
curl -k -X POST 'https://localhost:8083/api/atm/cuentas/145/retiro'   -H 'Authorization: Bearer bancoxyz-atm-demo-token-2026'   -H 'Content-Type: application/json'   -d '{"monto":1}'
```

---

## 🔎 Actuator

Los servicios exponen endpoints de salud y los BFF exponen métricas de resiliencia según su configuración centralizada.

Ejemplos:

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

---

## 🧰 Scripts de apoyo

Desde la raíz:

```fish
fish "Semana 7/scripts/inicializar_bd.fish"
fish "Semana 7/scripts/verificar_bff.fish"
fish "Semana 7/scripts/verificar_actuator_resilience.fish"
fish "Semana 7/scripts/verificar_retiro_controlado.fish"
```

---

## ✅ Alcance de Semana 7

La base estable de Semana 7 deja funcionando y organizada la arquitectura distribuida previa e incorpora el flujo asíncrono de retiro con Kafka. Esta versión se utiliza como punto de partida para la Semana 8, donde se agregará OAuth2.0 y se reforzará el despliegue Cloud sin alterar el histórico de esta entrega.

---

**BancoXYZ · Grupo 13 · Desarrollo Backend III (PBY2203) · Semana 7**
