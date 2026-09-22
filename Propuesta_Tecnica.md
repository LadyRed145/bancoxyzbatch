Propuesta Técnica — BancoXYZ

Implementación de microservicios resilientes y seguridad con Spring Cloud — Semana 6

Asignatura: Desarrollo Backend III (PBY2203)
Actividad: Implementando microservicios y seguridad en la nube con Spring Cloud
Grupo: 13

1. Objetivo

La propuesta extiende BancoXYZ hacia una arquitectura distribuida capaz de centralizar configuración, descubrir servicios dinámicamente, aplicar autenticación y autorización por canal y mantener continuidad operativa frente a fallos del servicio bancario central.

El diseño conserva el bank-backend como responsable de la lógica bancaria y persistencia, mientras tres Backend for Frontend independientes —Web, Mobile y ATM— exponen contratos específicos para cada consumidor.

La solución se apoya en cuatro capacidades principales solicitadas por la actividad:

Spring Cloud Config Server para configuración centralizada.

Eureka Service Discovery para registro y descubrimiento.

Tolerancia a fallos mediante Circuit Breaker, Retry, Rate Limiter, timeout y fallback.

Autenticación y autorización mediante Bearer Tokens académicos y roles por canal.

Los datos utilizados corresponden a la continuidad de la migración realizada sobre el conjunto legacy indicado en la actividad (KariVillagran/bank_legacy_data).

2. Arquitectura propuesta

                          +----------------------+
                          |    Config Server     |
                          |        :8888         |
                          +----------+-----------+
                                     |
                        configuración centralizada
                                     |
        +----------------------------+----------------------------+
        |                            |                            |
+-------v-------+            +-------v--------+           +-------v-------+
|    BFF Web    |            |   BFF Mobile   |           |    BFF ATM    |
| HTTPS :8081   |            | HTTPS :8082    |           | HTTPS :8083   |
| ROLE_WEB      |            | ROLE_MOBILE    |           | ROLE_ATM      |
+-------+-------+            +-------+--------+           +-------+-------+
        |                            |                            |
        +----------------------------+----------------------------+
                                     |
                         Discovery + LoadBalancer
                                     |
                            +--------v---------+
                            |   Bank Backend   |
                            |    HTTP :8080    |
                            +--------+---------+
                                     |
                            +--------v---------+
                            |  PostgreSQL 17   |
                            |      :5432       |
                            +------------------+

                          +----------------------+
                          |    Eureka Server     |
                          |        :8761         |
                          +----------------------+

Todos los servicios de aplicación participan en Eureka. Los BFF consumen configuración externa desde Config Server y localizan BANK-BACKEND mediante Spring Cloud LoadBalancer.

3. Configuración centralizada

Se incorpora un Config Server en el puerto 8888 utilizando repositorio nativo para la entrega académica.

El repositorio central contiene configuraciones independientes para:

bff-web.properties
bff-mobile.properties
bff-atm.properties

La configuración externaliza elementos que no deben quedar rígidamente acoplados al código Java:

URL lógica del Bank Backend;

timeout técnico;

Eureka Server;

parámetros de LoadBalancer;

Circuit Breaker;

Retry;

Rate Limiter;

exposición de Actuator;

parámetros de observabilidad.

Esta estrategia permite modificar políticas operativas sin recompilar los BFF y mantiene consistencia entre servicios.

4. Service Discovery

Se utiliza Netflix Eureka en el puerto 8761.

Durante la ejecución se registran:

BANK-BACKEND
BFF-WEB
BFF-MOBILE
BFF-ATM

La pauta solicita tres microservicios correctamente registrados; la solución registra los tres BFF y adicionalmente el Bank Backend.

Los clientes no dependen de una IP fija del backend. Spring Cloud LoadBalancer utiliza el registro de Eureka para resolver la instancia disponible.

5. Patrón Backend for Frontend

La separación por canal se mantiene porque cada consumidor tiene necesidades distintas.

5.1 BFF Web

Puerto 8081 HTTPS.

Rol ROLE_WEB.

Expone información completa y detalle agregado.

Usa Mono.zip cuando necesita combinar información concurrentemente.

GET /api/web/cuentas
GET /api/web/cuentas/{id}
GET /api/web/cuentas/{id}/detalle

5.2 BFF Mobile

Puerto 8082 HTTPS.

Rol ROLE_MOBILE.

Reduce payload mediante DTOs y mapper específicos.

GET /api/mobile/cuentas
GET /api/mobile/cuentas/{id}/resumen

5.3 BFF ATM

Puerto 8083 HTTPS.

Rol ROLE_ATM.

Expone únicamente operaciones necesarias para el cajero.

GET  /api/atm/cuentas/{id}/saldo
POST /api/atm/cuentas/{id}/retiro

Ningún BFF consulta directamente PostgreSQL ni utiliza entidades JPA internas del Bank Backend.

6. Organización interna

Los BFF siguen una separación explícita de responsabilidades:

controller -> contrato HTTP
service    -> coordinación del caso de uso
client     -> comunicación con BANK-BACKEND + resiliencia
mapper     -> transformación de respuesta cuando corresponde
dto        -> contratos de entrada/salida
exception  -> normalización y traducción de errores
config     -> seguridad y configuración técnica

La capa client encapsula la comunicación WebClient, evitando que controladores y servicios conozcan detalles de infraestructura.

7. Circuit Breaker

Los tres BFF usan una instancia Resilience4j denominada bankbackend.

Configuración principal:

Sliding Window: COUNT_BASED
Tamaño de ventana: 5
Mínimo de llamadas: 3
Umbral de fallos: 50 %
OPEN: 10 segundos
Llamadas permitidas en HALF_OPEN: 2
Transición OPEN -> HALF_OPEN: automática

La evidencia funcional demostró:

CLOSED -> OPEN -> HALF_OPEN -> CLOSED

También se observó incremento de notPermittedCalls cuando el circuito se encontraba abierto, demostrando que las llamadas adicionales fueron rechazadas sin continuar hacia el backend.

8. Retry controlado

Las operaciones GET utilizan Retry con:

max-attempts = 3
wait-duration = 200 ms

Los tres BFF fueron validados con Bank Backend detenido. Actuator registró para cada lectura:

Attempt 1 -> RETRY
Attempt 2 -> RETRY
Attempt 3 -> ERROR

Esto demuestra tres intentos totales y una terminación controlada en 503 cuando la dependencia continúa indisponible.

8.1 Exclusión del retiro ATM

El POST /api/atm/cuentas/{id}/retiro se procesa con una ruta protegerSinRetry.

Esta decisión es deliberada: un retiro no es idempotente. Si el backend ejecutara el débito pero la respuesta se perdiera, un reintento automático podría producir un segundo débito. Por lo tanto, el Retry se limita a operaciones seguras de lectura.

9. Rate Limiter

Cada BFF incorpora Rate Limiter sobre la instancia bankbackend:

10 permisos por período
período: 1 segundo
timeout de adquisición: 0 ms

La validación funcional utilizó una ráfaga concurrente de 30 solicitudes por canal y produjo:

WEB    -> 10 HTTP 200 + 20 HTTP 429
MOBILE -> 10 HTTP 200 + 20 HTTP 429
ATM    -> 10 HTTP 200 + 20 HTTP 429

El operador se aplica por fuera del Circuit Breaker. Así, una solicitud rechazada por exceso de tráfico devuelve 429 Too Many Requests pero no incrementa los fallos del backend ni abre el circuito.

Esta separación fue comprobada observando el Circuit Breaker en estado CLOSED y failedCalls=0 después de la prueba de Rate Limiter.

10. Timeout y fallback

La comunicación hacia el Bank Backend utiliza un timeout configurable de 3s.

Los errores técnicos se normalizan en la capa client:

conexión no disponible -> BackendNoDisponibleException -> 503
exceso de tiempo        -> BackendTimeoutException      -> 504

Los errores funcionales recibidos desde el backend conservan su semántica HTTP cuando corresponde.

El fallback del Circuit Breaker evita respuestas 500 ambiguas y mantiene un contrato controlado durante indisponibilidad de infraestructura.

11. Autenticación y autorización

La seguridad es stateless y diferencia autenticación de autorización.

Roles:

ROLE_WEB
ROLE_MOBILE
ROLE_ATM

Resultados esperados y validados:

Sin Bearer Token            -> 401
Token desconocido           -> 401
Token válido de otro canal  -> 403
Token correcto              -> acceso permitido

Los BFF utilizan HTTPS con certificados PKCS12 académicos.

/actuator/health e /actuator/info pueden utilizarse para monitoreo, mientras los demás endpoints de Actuator requieren el rol correspondiente al canal.

12. Observabilidad

Se incorpora Spring Boot Actuator en los tres BFF.

Endpoints utilizados:

/actuator/health
/actuator/metrics
/actuator/circuitbreakers
/actuator/circuitbreakerevents
/actuator/retries
/actuator/retryevents
/actuator/ratelimiters
/actuator/ratelimiterevents

La evidencia más relevante se obtiene mediante:

health: disponibilidad de cada BFF;

circuitbreakers: estado y estadísticas del Circuit Breaker;

retryevents: número de intentos y resultado final;

códigos HTTP 200 y 429: evidencia funcional del Rate Limiter.

13. Persistencia y migración de datos

El Bank Backend conserva la responsabilidad exclusiva sobre PostgreSQL 17.

La entrega incluye:

Semana 6/database/01_schema.sql
Semana 6/database/02_seed_processed_snapshot.sql

Los scripts permiten reconstruir la base en un volumen nuevo y mantienen la entrega reproducible sin depender del estado local previo.

Los tres CSV legacy permanecen disponibles como trazabilidad de la migración.

14. Docker Compose

La solución incorpora un docker-compose.yml con siete servicios:

postgres
config-server
discovery-server
bank-backend
bff-web
bff-mobile
bff-atm

El Compose define:

red interna bancoxyz-net;

healthchecks;

dependencias condicionadas por salud;

volumen persistente PostgreSQL;

variables de entorno para configuración sensible y parámetros operativos;

montaje de config-repo en Config Server.

La definición fue validada mediante docker compose config.

15. Verificación y reproducibilidad

La entrega incluye cuatro scripts Fish:

inicializar_bd.fish
verificar_bff.fish
verificar_actuator_resilience.fish
verificar_retiro_controlado.fish

inicializar_bd.fish

Levanta PostgreSQL de manera aislada y comprueba disponibilidad y esquema.

verificar_bff.fish

Comprueba funcionalidad, HTTPS, autenticación, autorización cruzada y validaciones seguras.

verificar_actuator_resilience.fish

Ejecuta una auditoría no destructiva de Actuator y Resilience4j e incluye una prueba real del Rate Limiter.

verificar_retiro_controlado.fish

Valida el flujo de retiro mediante fixture controlado sin alterar permanentemente las cuentas utilizadas como evidencia.

Las pruebas destructivas de Retry y Circuit Breaker se ejecutan manualmente para evitar que una auditoría normal detenga servicios automáticamente.

16. Resultados funcionales observados

Durante la validación previa a la entrega se obtuvo:

Prueba

Resultado

Reactor Maven

7/7 SUCCESS

Health WEB/MOBILE/ATM

200 / UP

Retry WEB

intentos 1, 2, 3 + 503 final

Retry MOBILE

intentos 1, 2, 3 + 503 final

Retry ATM GET

intentos 1, 2, 3 + 503 final

Rate Limiter WEB

10×200 + 20×429

Rate Limiter MOBILE

10×200 + 20×429

Rate Limiter ATM

10×200 + 20×429

Circuit Breaker

CLOSED → OPEN → HALF_OPEN → CLOSED

OPEN

notPermittedCalls > 0

Recuperación

2 probes correctos → CLOSED

17. Correspondencia con la pauta

Criterio 1 — Config Server

Se implementa un servidor de configuración centralizado y funcional, consumido por los tres BFF.

Criterio 2 — Service Discovery

Eureka registra correctamente los tres BFF exigidos y, adicionalmente, Bank Backend.

Criterio 3 — Tres microservicios con tolerancia a fallos y autenticación

WEB, MOBILE y ATM incorporan:

Circuit Breaker;

fallback;

Retry seguro;

Rate Limiter;

timeout;

autenticación por token;

autorización por rol;

observabilidad con Actuator.

Criterio 4 — Autenticación y autorización

La solución distingue credenciales inválidas (401) de credenciales válidas sin permiso (403) y restringe cada API al rol de su canal.

18. Decisiones técnicas relevantes

Configuración fuera del código: reduce duplicación y facilita ajustes operativos.

Discovery en lugar de IP fija: disminuye acoplamiento entre servicios.

Retry sólo en lecturas: evita efectos secundarios duplicados.

Rate Limiter fuera del Circuit Breaker: un exceso de tráfico no se interpreta como falla del backend.

Fallback semántico: evita 500 genéricos durante fallos técnicos conocidos.

BFF independientes: cada canal controla su contrato, seguridad y evolución.

Actuator protegido: observabilidad disponible sin exponer indiscriminadamente información operativa.

Docker reproducible: reduce diferencias entre ambientes y facilita la evaluación.

19. Consideraciones para producción

La implementación actual es apropiada para la demostración académica. Para un entorno productivo se recomienda evolucionar hacia:

OAuth2/OIDC y JWT firmados;

identidad centralizada;

secret manager externo;

certificados emitidos por una CA;

TLS interno;

observabilidad centralizada;

trazas distribuidas;

alertamiento;

Testcontainers;

CI/CD;

configuración separada por ambientes;

políticas de Rate Limiting por consumidor o credencial.

20. Conclusión

BancoXYZ cumple el objetivo de la Semana 6 al integrar configuración centralizada, descubrimiento de servicios, tres BFF con tolerancia a fallos y un sistema funcional de autenticación y autorización.

La solución no se limita a declarar dependencias: los mecanismos de resiliencia fueron ejecutados y observados en runtime. Se comprobó Retry de tres intentos, Rate Limiter con respuestas 429, apertura y recuperación del Circuit Breaker, fallback ante indisponibilidad y recuperación completa a estado CLOSED.

La arquitectura mantiene además las decisiones de desacoplamiento construidas en semanas anteriores, conservando al Bank Backend como dueño de la persistencia y utilizando los BFF como fronteras específicas de cada canal.