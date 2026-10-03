# Propuesta Técnica — BancoXYZ

## Arquitectura resiliente y orientada a eventos con Spring Cloud y Apache Kafka — Semana 7

**Asignatura:** Desarrollo Backend III (PBY2203)  
**Grupo:** 13

## 1. Objetivo

La propuesta técnica de Semana 7 da continuidad a BancoXYZ mediante una arquitectura distribuida que mantiene configuración centralizada, descubrimiento de servicios y tolerancia a fallos, e incorpora mensajería asíncrona con Apache Kafka en el proceso de retiro.

El `bank-backend` continúa concentrando la lógica bancaria y la persistencia. Los tres Backend for Frontend —Web, Mobile y ATM— mantienen contratos específicos para cada consumidor. Kafka desacopla el resultado de una operación de retiro de su procesamiento posterior mediante el evento `RetiroRealizadoEvent`.

## 2. Componentes

La solución está compuesta por:

- Spring Cloud Config Server.
- Netflix Eureka Discovery Server.
- Bank Backend.
- BFF Web.
- BFF Mobile.
- BFF ATM.
- PostgreSQL 17.
- Apache Kafka.
- Resilience4j.
- Docker Compose.

## 3. Arquitectura

```text
BFF Web -----+
BFF Mobile --+--> Eureka / LoadBalancer --> Bank Backend --> PostgreSQL
BFF ATM -----+                              |
                                             +--> RetiroRealizadoEvent
                                                      |
                                                      v
                                             Kafka bancoxyz.retiros
                                                      |
                                                      v
                                             RetiroKafkaConsumer

Config Server --> configuración centralizada de los BFF
Eureka Server --> registro y descubrimiento de servicios
```

## 4. Configuración centralizada

Config Server se ejecuta en el puerto `8888` con repositorio nativo y entrega configuración independiente para:

- `bff-web.properties`
- `bff-mobile.properties`
- `bff-atm.properties`

Se externalizan parámetros de Eureka, backend lógico, timeout, Circuit Breaker, Retry, Rate Limiter y Actuator.

## 5. Service Discovery

Eureka se ejecuta en `8761`. Se registran `BANK-BACKEND`, `BFF-WEB`, `BFF-MOBILE` y `BFF-ATM`. Los BFF consumen el backend mediante descubrimiento de servicios y Spring Cloud LoadBalancer en vez de depender de una IP rígida.

## 6. Backend for Frontend

### 6.1 Web

- HTTPS `8081`.
- Rol `ROLE_WEB`.
- Contratos orientados a vistas completas y detalle agregado.

```text
GET /api/web/cuentas
GET /api/web/cuentas/{id}
GET /api/web/cuentas/{id}/detalle
```

### 6.2 Mobile

- HTTPS `8082`.
- Rol `ROLE_MOBILE`.
- Payload reducido mediante DTOs y mappers.

```text
GET /api/mobile/cuentas
GET /api/mobile/cuentas/{id}/resumen
```

### 6.3 ATM

- HTTPS `8083`.
- Rol `ROLE_ATM`.
- Operaciones limitadas al contexto del cajero.

```text
GET  /api/atm/cuentas/{id}/saldo
POST /api/atm/cuentas/{id}/retiro
```

## 7. Resilience4j

La comunicación entre BFF y Bank Backend mantiene las políticas implementadas previamente:

- Circuit Breaker.
- Retry de hasta 3 intentos para operaciones seguras.
- Rate Limiter.
- Timeout.
- Respuestas controladas mediante fallback/traducción de errores.

El retiro ATM se mantiene sin Retry automático porque no es una operación idempotente y un reintento podría provocar un débito duplicado.

Ante indisponibilidad del Bank Backend, el BFF entrega `HTTP 503 Service Unavailable` de forma controlada.

## 8. Arquitectura de eventos con Kafka

La Semana 7 incorpora Apache Kafka al flujo de retiro.

### 8.1 Evento

`RetiroRealizadoEvent` representa una operación de retiro terminada correctamente y contiene:

- `cuentaId`
- `monto`
- `saldoFinal`
- `tipo`

### 8.2 Productor

`RetiroKafkaProducer` publica el evento en:

```text
bancoxyz.retiros
```

La cuenta se utiliza como clave del mensaje.

### 8.3 Consumidor

`RetiroKafkaConsumer` escucha el mismo tópico dentro del grupo:

```text
bancoxyz-retiros-group
```

El consumidor recibe y procesa la información del retiro de forma asíncrona.

### 8.4 Tópico

`KafkaTopicConfig` crea `bancoxyz.retiros` con una partición y factor de replicación `1`, configuración apropiada para el entorno académico local.

## 9. Orden del retiro

El orden implementado prioriza la operación bancaria principal:

1. validar cuenta;
2. validar saldo;
3. ejecutar retiro;
4. persistir el saldo actualizado en PostgreSQL;
5. crear `RetiroRealizadoEvent`;
6. publicar el evento en Kafka;
7. consumir el evento de forma asíncrona.

Así, Kafka complementa el proceso y no sustituye la transacción bancaria principal.

## 10. Docker Compose

`docker-compose.yml` orquesta:

- PostgreSQL;
- Kafka;
- Config Server;
- Discovery Server;
- Bank Backend;
- BFF Web;
- BFF Mobile;
- BFF ATM.

Dentro de la red Docker, Bank Backend utiliza:

```text
KAFKA_BOOTSTRAP_SERVERS=kafka:29092
```

Kafka expone además `localhost:9092` para acceso desde el host.

Las dependencias de inicio utilizan healthchecks para evitar levantar servicios consumidores antes de que sus dependencias principales estén disponibles.

## 11. Seguridad

La base Semana 7 conserva el mecanismo académico stateless mediante Bearer Tokens y roles por canal:

- `ROLE_WEB`
- `ROLE_MOBILE`
- `ROLE_ATM`

Los BFF utilizan HTTPS con certificados PKCS12 académicos. OAuth2.0 se reserva para la evolución solicitada en Semana 8, evitando alterar retrospectivamente la implementación entregada de Semana 7.

## 12. Organización del código

```text
bancoxyzbatch/
├── docker-compose.yml
├── pom.xml
├── README.md
├── Propuesta_Tecnica.md
└── Semana 7/
    ├── bank-backend/
    │   └── src/main/java/
    │       └── cl/duoc/bancoxyz/
    │           ├── backend/
    │           │   ├── kafka/
    │           │   └── ...
    │           └── event/
    ├── bff/
    ├── config-repo/
    ├── config-server/
    ├── database/
    ├── discovery-server/
    └── scripts/
```

Los directorios Maven `target/` no se versionan.

## 13. Compilación y despliegue

Build agregado:

```fish
./mvnw clean package -DskipTests
```

Validación de Compose:

```fish
docker compose config
```

Despliegue:

```fish
docker compose up --build -d
```

## 14. Resultado técnico

La versión estable de Semana 7 conserva la arquitectura de microservicios y resiliencia de BancoXYZ e incorpora un flujo de eventos de retiro basado en Kafka. El proyecto queda preparado como base limpia para la Semana 8 sin mezclar todavía la implementación de OAuth2.0 correspondiente a esa etapa.
