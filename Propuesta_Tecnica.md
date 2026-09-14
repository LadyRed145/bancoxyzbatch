# Propuesta Técnica — BancoXYZ
## Implementación del patrón Backend for Frontend (BFF) — Semana 5

## 1. Estrategia

Implemento tres BFF independientes porque Web, Mobile y ATM tienen necesidades diferentes de datos, latencia y seguridad. El Bank Backend mantiene la lógica y el acceso a PostgreSQL; los BFF se limitan a exponer endpoints personalizados, adaptar contratos, coordinar información y aplicar seguridad específica por canal.

```text
Web -> BFF Web \
Mobile -> BFF Mobile ---> Bank Backend ---> PostgreSQL
ATM -> BFF ATM /
```

Esta decisión evita que los frontends dependan de detalles internos de persistencia, tablas o entidades JPA del backend.

## 2. Organización interna y desacoplamiento

Para alinear la estructura del proyecto con las responsabilidades propias de un BFF, separo:

```text
controller -> contrato HTTP del canal
service    -> coordinación del caso de uso
client     -> integración HTTP con Bank Backend
mapper     -> transformación al contrato del canal
dto        -> datos de entrada/salida
exception  -> traducción de errores
config     -> seguridad y configuración HTTP
```

La capa `client` encapsula `WebClient`, URL, timeout y fallos de comunicación. De esta forma, si cambia la implementación interna del Bank Backend pero conserva su contrato HTTP, el impacto sobre el BFF se mantiene acotado.

En Mobile y ATM utilizo mappers explícitos porque existe una reducción real del contrato. En Web no agrego un mapper artificial: el canal conserva una respuesta rica y su transformación principal consiste en agregar información concurrentemente.

## 3. BFF Web

El canal Web entrega la información más completa y dispone de un endpoint agregado de detalle. Para evitar dos esperas secuenciales, la agregación utiliza `Mono.zip`.

- Puerto: `8081` HTTPS.
- Rol: `ROLE_WEB`.
- Cuentas completas: 2174 B.
- Detalle agregado: 449 B.

Endpoints:

```text
GET /api/web/cuentas
GET /api/web/cuentas/{id}
GET /api/web/cuentas/{id}/detalle
```

## 4. BFF Mobile

El canal Mobile utiliza DTOs reducidos para disminuir ancho de banda y procesamiento.

- Puerto: `8082` HTTPS.
- Rol: `ROLE_MOBILE`.
- Lista resumida: 784 B.
- Resumen individual: 93 B.

El `MobileCuentaMapper` transforma la respuesta extensa del Bank Backend en un contrato estable compuesto solo por los datos que necesita el canal.

La lista Mobile representa aproximadamente 64 % menos datos que la respuesta Web completa.

## 5. BFF ATM

El ATM expone únicamente operaciones críticas: consulta de saldo y retiro. Tanto la entrada como la respuesta usan DTOs mínimos.

- Puerto: `8083` HTTPS.
- Rol: `ROLE_ATM`.
- Saldo: 61 B.
- Retiro: 65 B.

`AtmCuentaMapper` evita exponer al cajero campos internos del modelo central. El retiro se valida en el BFF y nuevamente en el Bank Backend.

## 6. Timeouts y servicios no disponibles

Cada BFF incorpora un timeout configurable para no quedar esperando indefinidamente una dependencia lenta:

```properties
backend.timeout=${BACKEND_TIMEOUT:3s}
```

La política se aplica dentro de la capa `client`, no dentro del controlador ni del servicio.

Traducción de fallos:

- respuesta funcional del backend: se conserva su status original;
- conexión rechazada o backend no disponible: `503 Service Unavailable`;
- tiempo máximo excedido: `504 Gateway Timeout`.

Con esto reduzco el riesgo de acumular solicitudes, conexiones y threads esperando una dependencia que no responde, y evito que un fallo de infraestructura se vea como un `500` ambiguo.

## 7. Optimización por canal

| Canal | Respuesta | Tamaño medido |
|---|---|---:|
| Web | cuentas completas | 2174 B |
| Web | detalle agregado | 449 B |
| Mobile | cuentas resumidas | 784 B |
| Mobile | resumen individual | 93 B |
| ATM | saldo | 61 B |
| ATM | retiro | 65 B |

Además:

- Web agrega información concurrentemente con `Mono.zip`.
- Mobile reduce campos mediante DTO + mapper.
- ATM restringe operaciones y payloads al mínimo necesario.
- Los BFF comprimen JSON cuando supera el umbral configurado.
- Ningún BFF consulta directamente PostgreSQL.

## 8. Autenticación y autorización

Los tres BFF reconocen los Bearer Tokens académicos configurados, pero cada BFF autoriza únicamente su rol. Esto permite distinguir autenticación de autorización:

```text
401 -> token ausente o desconocido
403 -> token válido con rol de otro canal
```

Se validaron cruces WEB->MOBILE, MOBILE->ATM y ATM->WEB con respuesta 403.

## 9. HTTPS y certificados

Web, Mobile y ATM utilizan HTTPS mediante certificados PKCS12 autofirmados para el entorno local académico. Las pruebas automáticas muestran subject, issuer y vigencia de cada certificado.

## 10. Persistencia y trazabilidad de datos

Incluyo los tres archivos legacy originales completos:

- `intereses.csv`
- `cuentas_anuales.csv`
- `transacciones.csv`

Cada uno conserva 1000 registros de origen. Para que la ejecución de Semana 5 no dependa del volumen PostgreSQL de mi equipo, la entrega incorpora un esquema SQL y un snapshot procesado reproducible.

El snapshot contiene 50 cuentas procesadas, 20 estados anuales, 482 transacciones procesadas y 265 resúmenes diarios. Las cuentas usadas por las evidencias BFF (101–108) quedan alineadas con los resultados validados.

PostgreSQL 17 se levanta mediante `docker-compose.yml` y carga automáticamente los scripts SQL cuando se crea un volumen nuevo.

## 11. Modularidad y escalabilidad

La solución se divide en cuatro aplicaciones Maven independientes:

```text
bank-backend
bff-web
bff-mobile
bff-atm
```

El POM raíz actúa como agregador, por lo que puedo comprobar todo el proyecto mediante `./mvnw clean compile`.

La separación adicional `controller/service/client/mapper/dto/exception/config` permite sustituir una integración o transformar un contrato sin obligarme a reescribir el resto del BFF.

## 12. Manejo de errores

Se utilizan códigos HTTP semánticos:

- `400`: solicitud inválida.
- `404`: cuenta inexistente.
- `409`: cuenta inactiva o saldo insuficiente.
- `503`: Bank Backend no disponible.
- `504`: timeout de comunicación con Bank Backend.
- `200`: operación correcta.

## 13. Verificación

`verificar_bff.fish` comprueba funcionalidad, payloads, HTTPS, certificados, 401, 403 y validación de retiro.

`verificar_retiro_controlado.fish` crea un fixture temporal, ejecuta un retiro real de `$1.00`, verifica la diferencia de saldo y elimina la cuenta temporal. Así demuestro la operación crítica sin alterar la cuenta original.

## 14. Buenas prácticas

Durante la implementación priorizo:

- endpoints personalizados por canal;
- bajo acoplamiento con servicios internos;
- DTOs explícitos;
- mappers solo donde aportan una transformación real;
- integración HTTP encapsulada en `client`;
- timeout configurable;
- errores 503/504 para fallos de infraestructura;
- mínimo privilegio;
- validación defensiva;
- transporte HTTPS;
- sesiones stateless;
- configuración externalizable;
- Maven multi-módulo;
- datos reproducibles con Docker Compose;
- pruebas repetibles y fixtures temporales.

## 15. Evolución productiva

La seguridad actual es deliberadamente académica y local. En producción reemplazaría los tokens estáticos y certificados autofirmados por:

- OAuth2 / OpenID Connect.
- JWT firmados y de corta duración.
- Proveedor de identidad centralizado.
- Gestión externa de secretos.
- Certificados emitidos por una CA.
- TLS también entre BFF y Bank Backend.
- Circuit breaker y retry controlado para operaciones idempotentes.
- Rate limiting.
- Observabilidad con métricas y trazabilidad.
- Testcontainers y CI/CD.

## 16. Conclusión

La propuesta cumple el objetivo del patrón BFF al entregar tres backends especializados, optimizados y protegidos de forma independiente. Además, incorpora endpoints personalizados, desacoplamiento explícito mediante una capa `client`, transformación por canal con mappers, timeout controlado y respuestas 503/504 ante fallos de infraestructura, manteniendo la lógica central y la persistencia en un Bank Backend común.
