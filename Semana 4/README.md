# Banco XYZ - Backend for Frontend

## Descripción

El presente proyecto corresponde a la implementación del patrón arquitectónico Backend for Frontend (BFF) para el sistema Banco XYZ.

La solución se desarrolla a partir del backend construido en las actividades anteriores, donde los datos bancarios son procesados y almacenados en PostgreSQL. Para esta actividad se implementa una capa intermedia que permite adaptar el acceso a la información dependiendo del tipo de cliente que consume los servicios.

Se implementaron tres Backend for Frontend independientes:

- BFF Web
- BFF Mobile
- BFF ATM

Cada uno posee sus propios endpoints, configuración y mecanismos de autenticación. Los BFF consumen los servicios expuestos por el backend principal mediante HTTP y no acceden directamente a la base de datos.

## Objetivo

El objetivo principal es aplicar el patrón Backend for Frontend para entregar servicios adaptados a las necesidades de diferentes canales de acceso.

La implementación busca solucionar principalmente los siguientes aspectos:

- Separar las necesidades de los clientes Web, Mobile y ATM.
- Evitar que los clientes accedan directamente a la base de datos.
- Centralizar el acceso a la información mediante un backend principal.
- Reducir la cantidad de información enviada a dispositivos móviles.
- Mantener las operaciones críticas del cajero automático de forma simple y controlada.
- Aplicar autenticación diferenciada según el canal.
- Mantener una separación clara entre la lógica del backend y las necesidades de cada cliente.

## Arquitectura implementada

La arquitectura utilizada se divide en cuatro aplicaciones principales.

El backend central se encuentra conectado a PostgreSQL y es responsable de entregar la información procesada.

Sobre este backend se encuentran los tres BFF, cada uno destinado a un tipo de cliente.

La comunicación se realiza de la siguiente forma:

Cliente Web -> BFF Web -> Bank Backend -> PostgreSQL

Cliente Mobile -> BFF Mobile -> Bank Backend -> PostgreSQL

Cliente ATM -> BFF ATM -> Bank Backend -> PostgreSQL

Los BFF utilizan WebClient para comunicarse con el backend central mediante solicitudes HTTP.

Una característica importante de la implementación es que ningún BFF establece una conexión directa con PostgreSQL. Esto permite mantener separadas las responsabilidades de cada componente.

## Componentes del proyecto

### Bank Backend

El proyecto `bank-backend` corresponde al backend principal de la solución.

Se encuentra ejecutándose en el puerto 8080.

Su función es exponer los servicios necesarios para consultar y modificar la información procesada por el sistema.

Entre los recursos disponibles se encuentran:

- Cuentas.
- Transacciones.
- Estados de cuenta.
- Resúmenes de transacciones.
- Operaciones de retiro.

El backend utiliza Spring Data JPA para acceder a PostgreSQL.

### BFF Web

El BFF Web se ejecuta en el puerto 8081.

Su objetivo es entregar información más completa al cliente Web, debido a que este tipo de cliente puede trabajar con interfaces más complejas y disponer de mayor capacidad para procesar información.

Entre sus funcionalidades se encuentran:

- Obtener todas las cuentas.
- Consultar una cuenta específica.
- Obtener el detalle de una cuenta.
- Consultar información asociada a los estados de cuenta.

También cuenta con autenticación mediante Spring Security y un rol específico para el canal Web.

### BFF Mobile

El BFF Mobile se ejecuta en el puerto 8082.

Este BFF fue diseñado considerando las restricciones habituales de una aplicación móvil, principalmente el consumo de datos y la necesidad de recibir respuestas más pequeñas.

Por este motivo, el BFF Mobile transforma la respuesta recibida desde el backend y entrega solamente los datos necesarios para la aplicación.

Por ejemplo, el resumen de una cuenta contiene:

- Identificador de cuenta.
- Nombre.
- Tipo.
- Estado.
- Saldo final.

De esta forma, información que puede ser necesaria para el backend pero que no es requerida por el cliente móvil no es enviada.

El BFF Mobile también utiliza autenticación mediante Spring Security y posee un rol independiente denominado MOBILE.

### BFF ATM

El BFF ATM se ejecuta en el puerto 8083.

Este BFF está orientado a las operaciones realizadas desde un cajero automático, por lo que se priorizan respuestas pequeñas y operaciones específicas.

Las principales operaciones implementadas son:

- Consulta de saldo.
- Retiro de dinero.

El acceso al BFF ATM se encuentra protegido mediante Spring Security y utiliza un usuario con rol ATM.

Las operaciones de retiro también cuentan con validaciones en el backend para controlar que:

- El monto sea mayor que cero.
- La cuenta exista.
- La cuenta se encuentre activa.
- El saldo disponible sea suficiente.

## Tecnologías utilizadas

Para la implementación se utilizaron las siguientes tecnologías:

- Java 21.
- Spring Boot 4.1.1.
- Spring Web.
- Spring WebFlux.
- Spring Data JPA.
- Spring Security.
- PostgreSQL 17.
- Maven.
- Docker.
- Postman.
- Git y GitHub.

## Estructura del proyecto

La estructura general utilizada es:

Semana 4/

    bank-backend/

    bff/

        bff-web/

        bff-mobile/

        bff-atm/

Cada BFF corresponde a una aplicación Spring Boot independiente.

Dentro de cada aplicación se separan las responsabilidades utilizando paquetes para configuración, controladores, servicios y DTO.

## Endpoints del Bank Backend

### Cuentas

Obtener todas las cuentas:

GET /api/cuentas

Obtener una cuenta:

GET /api/cuentas/{id}

### Transacciones

Obtener todas las transacciones:

GET /api/transacciones

Obtener una transacción:

GET /api/transacciones/{id}

### Estados de cuenta

Obtener los estados de cuenta:

GET /api/estados-cuenta

Obtener los estados de cuenta de una cuenta:

GET /api/estados-cuenta/cuenta/{cuentaId}

### Resúmenes

Obtener los resúmenes:

GET /api/resumenes

Obtener un resumen por fecha:

GET /api/resumenes/{fecha}

### Retiro

Realizar un retiro:

POST /api/cuentas/{id}/retiro

Ejemplo de solicitud:

{
    "monto": 10000
}

## Endpoints del BFF Web

Obtener las cuentas:

GET /api/web/cuentas

Consultar una cuenta:

GET /api/web/cuentas/{id}

Consultar el detalle de una cuenta:

GET /api/web/cuentas/{id}/detalle

El endpoint de detalle permite combinar información obtenida desde diferentes recursos del backend para entregar una respuesta más adecuada para el cliente Web.

## Endpoints del BFF Mobile

Obtener las cuentas en formato resumido:

GET /api/mobile/cuentas

Obtener el resumen de una cuenta:

GET /api/mobile/cuentas/{id}/resumen

Ejemplo de respuesta:

{
    "cuentaId": 145,
    "nombre": "Steve Rogers",
    "tipo": "ahorro",
    "estado": "PROCESADO",
    "saldoFinal": 1620.00
}

La respuesta es intencionalmente más pequeña que la información entregada por el backend principal.

## Endpoints del BFF ATM

Consultar el saldo:

GET /api/atm/cuentas/{id}/saldo

Ejemplo:

GET /api/atm/cuentas/145/saldo

Respuesta:

{
    "cuentaId": 145,
    "nombre": "Steve Rogers",
    "saldoDisponible": 1620.00
}

Realizar un retiro:

POST /api/atm/cuentas/{id}/retiro

Ejemplo:

POST /api/atm/cuentas/145/retiro

Body:

{
    "monto": 500
}

La solicitud es recibida por el BFF ATM y posteriormente enviada al backend principal, que realiza las validaciones y actualiza el saldo correspondiente.

## Seguridad

Para controlar el acceso a los diferentes canales se incorporó Spring Security.

Cada BFF posee credenciales y un rol diferente.

BFF Web:

Usuario: web

Rol: WEB

BFF Mobile:

Usuario: mobile

Rol: MOBILE

BFF ATM:

Usuario: atm

Rol: ATM

Las solicitudes que intentan acceder a los recursos protegidos sin autenticación son rechazadas.

En las pruebas realizadas se verificó el comportamiento mediante Postman utilizando solicitudes sin credenciales y solicitudes con credenciales válidas.

Una solicitud sin autenticación retorna:

401 Unauthorized

Mientras que una solicitud con las credenciales correspondientes permite acceder al recurso.

## Flujo de una solicitud

Por ejemplo, para consultar el saldo desde el canal ATM, el cliente realiza la siguiente solicitud:

GET http://localhost:8083/api/atm/cuentas/145/saldo

El BFF ATM recibe la solicitud y valida la autenticación.

Posteriormente realiza una solicitud al backend principal:

GET http://localhost:8080/api/cuentas/145

El backend consulta la información almacenada en PostgreSQL y devuelve los datos de la cuenta.

Finalmente, el BFF ATM transforma la información y entrega solamente los datos necesarios para el cajero:

{
    "cuentaId": 145,
    "nombre": "Steve Rogers",
    "saldoDisponible": 1620.00
}

Este flujo permite que el cliente ATM no tenga que conocer la estructura completa de los datos entregados por el backend.

## Configuración

El backend principal utiliza las siguientes propiedades:

server.port=8080

spring.datasource.url=jdbc:postgresql://localhost:5432/bancoxyz

Los BFF utilizan el backend principal como origen de datos.

BFF Web:

server.port=8081

backend.base-url=http://localhost:8080

BFF Mobile:

server.port=8082

backend.base-url=http://localhost:8080

BFF ATM:

server.port=8083

backend.base-url=http://localhost:8080

## Ejecución

Antes de iniciar las aplicaciones se debe disponer de PostgreSQL funcionando.

Si se utiliza Docker Compose, se puede iniciar el entorno mediante:

docker compose up -d

Luego se debe iniciar el backend principal desde la carpeta correspondiente:

cd bank-backend

mvn spring-boot:run

Posteriormente se pueden iniciar los tres BFF de manera independiente.

Para Web:

cd bff/bff-web

mvn spring-boot:run

Para Mobile:

cd bff/bff-mobile

mvn spring-boot:run

Para ATM:

cd bff/bff-atm

mvn spring-boot:run

Los servicios deben quedar disponibles en los siguientes puertos:

Bank Backend: 8080

BFF Web: 8081

BFF Mobile: 8082

BFF ATM: 8083

## Pruebas realizadas

Las pruebas de funcionamiento fueron realizadas utilizando Postman.

Se verificó el acceso directo al backend principal y posteriormente el acceso a través de cada BFF.

En el BFF Web se verificó la consulta de cuentas y el detalle de una cuenta.

En el BFF Mobile se verificó que la información entregada sea reducida respecto de la respuesta original del backend.

En el BFF ATM se verificó la consulta de saldo y la operación de retiro.

También se realizaron pruebas de seguridad utilizando solicitudes sin autenticación y solicitudes con credenciales válidas.

Las solicitudes sin autenticación fueron rechazadas con código HTTP 401, mientras que las solicitudes autenticadas fueron procesadas correctamente.

## Resultado de la implementación

La implementación permite disponer de diferentes interfaces de acceso sobre un mismo backend.

El cliente Web recibe información más completa y puede utilizar operaciones que requieren mayor cantidad de datos.

El cliente Mobile recibe respuestas reducidas y adaptadas a sus necesidades.

El cliente ATM dispone de operaciones específicas y simples relacionadas con las funciones principales de un cajero automático.

Además, los tres canales se encuentran separados mediante aplicaciones independientes y poseen mecanismos de autenticación diferenciados.

## Conclusión

La implementación del patrón Backend for Frontend permitió adaptar el backend del Banco XYZ a diferentes tipos de clientes sin necesidad de entregar la misma información a todos los consumidores.

La separación de los BFF permite que cada canal tenga sus propios endpoints y pueda manejar las necesidades particulares de Web, Mobile y ATM.

La solución también mantiene una separación entre los clientes, los BFF y la base de datos, ya que los clientes no acceden directamente a PostgreSQL y los BFF consumen los servicios proporcionados por el backend principal.

Finalmente, la incorporación de Spring Security permite proteger los diferentes canales mediante autenticación y roles específicos, especialmente en el caso del ATM, donde se realizan operaciones críticas como consulta de saldo y retiro de dinero.