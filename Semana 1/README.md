# Banco XYZ Batch

Proyecto de migración y modernización de procesos batch bancarios utilizando **Spring Boot**, **Spring Batch** y **PostgreSQL**.

El sistema procesa archivos CSV provenientes de procesos legacy del Banco XYZ y ejecuta tres procesos principales:

- Procesamiento diario de transacciones.
- Cálculo mensual de intereses.
- Generación de estados de cuenta anuales.

El proyecto incorpora validación de datos, manejo de errores, detección de anomalías, persistencia, trazabilidad de ejecuciones e idempotencia.

---

## Tecnologías utilizadas

- Java 21
- Spring Boot 4.1.0
- Spring Batch 6
- Spring Data JPA
- Hibernate
- PostgreSQL 17
- Maven
- Docker / Docker Compose
- Lombok
- Jakarta Validation
- Git / GitHub

---

## Arquitectura general

Cada proceso batch sigue el modelo principal de Spring Batch:

```text
CSV
 ↓
ItemReader
 ↓
ItemProcessor
 ↓
ItemWriter
 ↓
PostgreSQL
```

Además, el sistema incorpora Steps complementarios para reconciliación, generación de reportes y control de registros que desaparecen entre ejecuciones.

Spring Batch utiliza un `JobRepository` JDBC persistido en PostgreSQL, permitiendo almacenar metadata de Jobs y Steps.

---

## Estructura del proyecto

```text
src/main/java/cl/duoc/bancoxyzbatch
│
├── config
│   ├── BatchInfrastructureConfig
│   ├── BatchRunContext
│   ├── ControlledJobRunner
│   ├── CuentaInteresReaderConfig
│   ├── MovimientoAnualReaderConfig
│   └── TransaccionReaderConfig
│
├── exception
│   └── ReglaNegocioException
│
├── job
│   ├── CuentaInteresJobConfig
│   ├── EstadoCuentaAnualJobConfig
│   └── TransaccionJobConfig
│
├── listener
│   └── RegistroRechazadoSkipListener
│
├── model
├── processor
├── repository
├── tasklet
└── writer
```

Los archivos de entrada se encuentran en:

```text
src/main/resources/data/
```

y corresponden a:

```text
transacciones.csv
intereses.csv
cuentas_anuales.csv
```

---

# Jobs implementados

## 1. transaccionJob

Procesa las transacciones diarias del banco.

Archivo de entrada:

```text
src/main/resources/data/transacciones.csv
```

Formato:

```text
id,fecha,monto,tipo
```

### Validaciones

El proceso valida:

- Identificador de transacción.
- Fecha.
- Monto.
- Tipo de transacción.
- Montos iguales a cero.
- Tipos distintos de `debito` y `credito`.

### Normalización

Cuando se detecta un débito con monto negativo, el sistema lo normaliza utilizando su valor absoluto.

El registro queda identificado con:

```text
estado = CORREGIDO
```

### Detección de duplicados

Se consideran posibles duplicados aquellas transacciones que poseen simultáneamente:

```text
misma fecha
+
mismo monto
+
mismo tipo
```

aunque tengan identificadores diferentes.

La primera transacción se conserva y las posteriores quedan marcadas como:

```text
estado = DUPLICADO
```

junto con una observación que identifica la transacción original.

### Resumen diario

El Job incorpora un Step adicional:

```text
resumenTransaccionDiariaStep
```

que genera la tabla:

```text
resumen_transacciones_diarias
```

El reporte almacena por fecha:

- Cantidad de transacciones válidas.
- Total de créditos.
- Total de débitos.
- Saldo neto diario.

El cálculo utilizado para el saldo neto es:

```text
saldo_neto = total_creditos - total_debitos
```

Los registros `RECHAZADO` y `DUPLICADO` no se incorporan a los totales financieros.

---

## 2. cuentaInteresJob

Procesa el cálculo mensual de intereses de cuentas bancarias.

Archivo de entrada:

```text
src/main/resources/data/intereses.csv
```

Formato:

```text
cuenta_id,nombre,saldo,edad,tipo
```

### Tasas utilizadas

Para efectos del caso académico se definieron las siguientes reglas:

```text
Cuenta de ahorro = 1%
Préstamo         = 2%
```

### Cálculo

```text
interes = saldo × tasa
saldo_final = saldo + interes
```

Los resultados se redondean a dos decimales utilizando `HALF_UP`.

### Estados posibles

```text
PROCESADO
SIN_INTERES
RECHAZADO
```

Las cuentas con saldo cero quedan como:

```text
SIN_INTERES
```

Los tipos de cuenta no soportados quedan como:

```text
RECHAZADO
```

y se registra una observación indicando la causa.

---

## 3. estadoCuentaAnualJob

Procesa movimientos bancarios y genera un estado consolidado por cuenta y año.

Archivo de entrada:

```text
src/main/resources/data/cuentas_anuales.csv
```

Formato:

```text
cuenta_id,fecha,transaccion,monto,descripcion
```

Se consideran los movimientos:

```text
deposito
retiro
compra
```

Los depósitos se normalizan como valores positivos.

Los retiros y compras se normalizan como valores negativos.

El resultado se persiste en:

```text
estados_cuenta_anuales
```

con información de:

- Cuenta.
- Año.
- Total de depósitos.
- Total de retiros.
- Total de compras.
- Saldo anual.

Existe una restricción única por:

```text
cuenta_id + anio
```

para evitar estados anuales duplicados.

---

# Manejo de errores

El sistema implementa tolerancia a fallos mediante Spring Batch.

Los Steps principales permiten controlar errores durante:

```text
READ
PROCESS
WRITE
```

Los registros descartados se almacenan en:

```text
registros_rechazados
```

La tabla registra información como:

- Job.
- Step.
- Fase del error.
- Número de línea.
- Contenido original.
- Tipo de error.
- Mensaje.
- JobInstance.
- Fecha de registro.

Se controlan, entre otros:

- Errores de parsing de archivos CSV.
- Registros mal formados.
- Errores de negocio.
- Movimientos con monto igual a cero.
- Datos incompatibles con las reglas definidas.

Un registro inválido puede ser omitido sin provocar necesariamente el fallo completo del Job.

---

# Reconciliación e idempotencia

Los tres procesos principales implementan reconciliación mediante Steps adicionales.

Cada registro procesado almacena:

```text
activo
ultima_instancia_id
```

Cuando una nueva ejecución procesa un archivo, los registros presentes se actualizan con el identificador de la nueva `JobInstance`.

Los registros que existían anteriormente pero ya no aparecen en el archivo actual son conservados históricamente y quedan:

```text
activo = false
```

Si posteriormente reaparecen, vuelven a:

```text
activo = true
```

Este mecanismo evita eliminar información histórica y permite ejecutar nuevamente los procesos sin generar duplicados funcionales.

---

# Spring Batch JDBC

El proyecto utiliza persistencia JDBC para la infraestructura de Spring Batch.

El esquema oficial para PostgreSQL se encuentra en:

```text
src/main/resources/db/schema-spring-batch-postgresql.sql
```

Entre las tablas de infraestructura se encuentran:

```text
BATCH_JOB_INSTANCE
BATCH_JOB_EXECUTION
BATCH_JOB_EXECUTION_PARAMS
BATCH_JOB_EXECUTION_CONTEXT
BATCH_STEP_EXECUTION
BATCH_STEP_EXECUTION_CONTEXT
```

---

# Base de datos

La base PostgreSQL puede levantarse utilizando Docker Compose.

```bash
docker compose up -d
```

Verificar el contenedor:

```bash
docker compose ps
```

La configuración predeterminada del proyecto es:

```text
Base de datos: bancoxyz
Usuario:        bancoxyz
Password:       bancoxyz123
Puerto:         5432
```

También pueden utilizarse variables de entorno:

```text
DB_URL
DB_USER
DB_PASSWORD
```

---

# Inicialización del esquema Spring Batch

Con PostgreSQL iniciado:

```bash
docker exec -i bancoxyz-postgres \
  psql -U bancoxyz -d bancoxyz \
  < src/main/resources/db/schema-spring-batch-postgresql.sql
```

Este procedimiento debe realizarse una sola vez sobre una base nueva.

Las tablas correspondientes al dominio son gestionadas por Hibernate durante el desarrollo mediante:

```properties
spring.jpa.hibernate.ddl-auto=update
```

---

# Compilar el proyecto

Linux/macOS:

```bash
./mvnw clean compile
```

Ejecutar pruebas:

```bash
./mvnw clean test
```

La prueba actual verifica que el contexto completo de Spring Boot pueda iniciarse correctamente.

---

# Ejecución de Jobs

La ejecución automática de todos los Jobs está deshabilitada:

```properties
spring.batch.job.enabled=false
```

El proyecto utiliza `ControlledJobRunner` para seleccionar explícitamente el proceso requerido.

Cada ejecución necesita:

```text
app.batch.job
app.batch.run-id
```

El `run-id` debe ser distinto para iniciar una nueva `JobInstance`.

## Transacciones

```bash
./mvnw spring-boot:run \
  -Dspring-boot.run.arguments="--app.batch.job=transaccionJob --app.batch.run-id=1"
```

## Intereses

```bash
./mvnw spring-boot:run \
  -Dspring-boot.run.arguments="--app.batch.job=cuentaInteresJob --app.batch.run-id=2"
```

## Estados de cuenta anuales

```bash
./mvnw spring-boot:run \
  -Dspring-boot.run.arguments="--app.batch.job=estadoCuentaAnualJob --app.batch.run-id=3"
```

Para una nueva ejecución deben utilizarse nuevos valores de `run-id`.

---

# Consulta de resultados

Ingresar a PostgreSQL:

```bash
docker exec -it bancoxyz-postgres \
  psql -U bancoxyz -d bancoxyz
```

## Transacciones

```sql
SELECT *
FROM transacciones_procesadas
ORDER BY id;
```

## Resumen diario

```sql
SELECT *
FROM resumen_transacciones_diarias
ORDER BY fecha;
```

## Intereses

```sql
SELECT *
FROM cuentas_intereses
ORDER BY cuenta_id;
```

## Estados anuales

```sql
SELECT *
FROM estados_cuenta_anuales
ORDER BY cuenta_id, anio;
```

## Registros rechazados

```sql
SELECT *
FROM registros_rechazados
ORDER BY id;
```

## Historial de Jobs

```sql
SELECT
    ji.job_instance_id,
    ji.job_name,
    je.job_execution_id,
    je.status,
    je.exit_code
FROM batch_job_instance ji
JOIN batch_job_execution je
    ON ji.job_instance_id = je.job_instance_id
ORDER BY je.job_execution_id DESC;
```

---

# Pruebas realizadas

Durante el desarrollo se verificaron:

- Ejecución correcta de los tres Jobs.
- Persistencia en PostgreSQL.
- Reejecución sin duplicación de información.
- Desactivación de registros ausentes.
- Reactivación de registros que reaparecen.
- Detección de transacciones duplicadas.
- Normalización de débitos negativos.
- Exclusión de duplicados del resumen financiero.
- Cálculo mensual de intereses.
- Consolidación anual sin doble acumulación.
- Manejo de errores técnicos de lectura.
- Manejo de errores de negocio durante procesamiento.
- Persistencia de registros rechazados.
- Ejecución de pruebas Maven sin fallos.

---

# Consideraciones de producción

La implementación corresponde a un entorno académico/desarrollo.

Para un entorno productivo se recomienda:

- Utilizar exclusivamente variables de entorno o un gestor de secretos.
- Utilizar migraciones versionadas con Flyway o Liquibase.
- Deshabilitar `ddl-auto=update`.
- Implementar monitoreo y métricas.
- Agregar una política formal de reintentos.
- Aumentar la cobertura de pruebas automatizadas.
- Ejecutar PostgreSQL mediante infraestructura administrada.
- Restringir credenciales y accesos según principio de mínimo privilegio.

---

## Autor = Grupo13

Proyecto desarrollado para la asignatura **Desarrollo Backend III**.

Implementación de modernización de procesos legacy bancarios utilizando Spring Batch.
