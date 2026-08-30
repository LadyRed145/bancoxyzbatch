# Banco XYZ Batch

Proyecto académico de modernización de procesos batch bancarios desarrollado con **Spring Boot**, **Spring Batch** y **PostgreSQL** para la asignatura **Desarrollo Backend III**.

La solución procesa archivos CSV provenientes de procesos legacy del Banco XYZ mediante tres Jobs principales:

- Procesamiento diario de transacciones.
- Cálculo mensual de intereses.
- Generación de estados de cuenta anuales.

Durante la Semana 3 se incorporaron mecanismos de **procesamiento paralelo, configuración dinámica de chunks, tolerancia a fallos, retry, trazabilidad, persistencia de metadatos y pruebas comparativas de rendimiento**.

---

## Tecnologías utilizadas

- Java 21
- Spring Boot 4.1.1
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

# Arquitectura general

Cada proceso principal utiliza el modelo de procesamiento por chunks de Spring Batch:

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

La solución incorpora además:

```text
JobRepository JDBC
        │
        ├── Persistencia de ejecuciones
        ├── Metadata de Jobs
        └── Metadata de Steps

ThreadPoolTaskExecutor
        │
        └── Procesamiento paralelo configurable

Fault Tolerance
        │
        ├── Retry
        ├── Skip
        └── Registro de errores

Tasklets complementarios
        │
        ├── Reconciliación
        ├── Detección de duplicados
        └── Generación de resúmenes
```

Los Readers utilizados en procesamiento concurrente se encuentran sincronizados mediante `SynchronizedItemStreamReader`, evitando accesos simultáneos inseguros al archivo de entrada.

---

# Estructura principal del proyecto

```text
src/main/java/cl/duoc/bancoxyzbatch
│
├── config
│   ├── BatchInfrastructureConfig
│   ├── BatchRetryConfig
│   ├── BatchRunContext
│   ├── BatchTaskExecutorConfig
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
│
├── processor
│   ├── CuentaInteresProcessor
│   ├── MovimientoAnualProcessor
│   └── TransaccionProcessor
│
├── repository
│
├── tasklet
│   ├── CuentaInteresReconciliationTasklet
│   ├── EstadoCuentaAnualReconciliationTasklet
│   ├── ResumenTransaccionDiariaTasklet
│   ├── TransaccionDuplicadosTasklet
│   └── TransaccionReconciliationTasklet
│
└── writer
    ├── CuentaInteresWriter
    ├── EstadoCuentaAnualWriter
    └── TransaccionWriter
```

Los archivos CSV utilizados como entrada se encuentran en:

```text
src/main/resources/data/
```

Archivos principales:

```text
transacciones.csv
intereses.csv
cuentas_anuales.csv
```

---

# Jobs implementados

## 1. `transaccionJob`

Procesa las transacciones diarias provenientes de:

```text
src/main/resources/data/transacciones.csv
```

Formato:

```text
id,fecha,monto,tipo
```

### Flujo del Job

```text
transaccionStep
        ↓
transaccionDuplicadosStep
        ↓
transaccionReconciliationStep
        ↓
resumenTransaccionDiariaStep
```

### Validaciones

Se validan:

- Identificador.
- Fecha.
- Monto.
- Tipo de transacción.
- Montos iguales a cero.
- Tipos distintos de `debito` y `credito`.

### Normalización

Un débito negativo se normaliza utilizando su valor absoluto y queda identificado como:

```text
CORREGIDO
```

### Detección de duplicados

Se consideran posibles duplicados los registros que poseen simultáneamente:

```text
misma fecha
+
mismo monto
+
mismo tipo
```

La primera ocurrencia se conserva y las posteriores quedan marcadas como:

```text
DUPLICADO
```

sin eliminarlas físicamente, manteniendo trazabilidad del registro original.

### Estados posibles

```text
PROCESADO
CORREGIDO
RECHAZADO
DUPLICADO
```

### Resumen diario

El Step:

```text
resumenTransaccionDiariaStep
```

genera información consolidada en:

```text
resumen_transacciones_diarias
```

incluyendo:

- Cantidad de transacciones válidas.
- Total de créditos.
- Total de débitos.
- Saldo neto diario.

Cálculo:

```text
saldo_neto = total_creditos - total_debitos
```

Los registros `RECHAZADO` y `DUPLICADO` no participan en los totales financieros.

---

## 2. `cuentaInteresJob`

Procesa:

```text
src/main/resources/data/intereses.csv
```

Formato:

```text
cuenta_id,nombre,saldo,edad,tipo
```

### Tasas utilizadas

Para el escenario académico:

```text
ahorro    = 1 %
prestamo  = 2 %
```

### Cálculo

```text
interes = saldo × tasa
saldo_final = saldo + interes
```

Los resultados monetarios son redondeados a dos decimales.

### Estados posibles

```text
PROCESADO
SIN_INTERES
RECHAZADO
```

Una cuenta con saldo cero queda como:

```text
SIN_INTERES
```

Un tipo de cuenta no soportado queda como:

```text
RECHAZADO
```

con la causa registrada en la observación correspondiente.

---

## 3. `estadoCuentaAnualJob`

Procesa:

```text
src/main/resources/data/cuentas_anuales.csv
```

Formato:

```text
cuenta_id,fecha,transaccion,monto,descripcion
```

Tipos aceptados:

```text
deposito
retiro
compra
```

Los depósitos se normalizan como valores positivos.

Los retiros y compras se consideran salidas de dinero.

El resultado consolidado se persiste en:

```text
estados_cuenta_anuales
```

con:

- Cuenta.
- Año.
- Total de depósitos.
- Total de retiros.
- Total de compras.
- Saldo anual.

Existe una restricción lógica por:

```text
cuenta_id + anio
```

que evita generar estados anuales duplicados.

---

# Reconciliación e idempotencia

Los tres Jobs incorporan mecanismos de reconciliación.

Cada registro procesado mantiene información de:

```text
activo
ultima_instancia_id
```

En cada nueva ejecución:

- Los registros presentes se actualizan con la nueva `JobInstance`.
- Los registros que desaparecen del archivo se conservan históricamente con `activo=false`.
- Si vuelven a aparecer, recuperan `activo=true`.

Esto permite reejecutar los Jobs sin generar duplicación funcional de información y sin eliminar historial.

---

# Procesamiento paralelo

La Semana 3 incorpora procesamiento concurrente mediante:

```text
ThreadPoolTaskExecutor
```

La cantidad de hilos y el tamaño de chunk son configurables:

```properties
app.batch.threads=4
app.batch.queue-capacity=20
app.batch.chunk-size=10
```

Estos valores pueden sobrescribirse desde la línea de comandos para ejecutar pruebas comparativas.

Ejemplo:

```bash
./mvnw spring-boot:run \
  -Dspring-boot.run.arguments="--app.batch.job=transaccionJob --app.batch.run-id=5001 --app.batch.threads=2 --app.batch.chunk-size=5"
```

Los logs muestran el hilo utilizado por cada procesamiento:

```text
[BATCH-PROCESSOR] hilo=batch-thread-1
[BATCH-PROCESSOR] hilo=batch-thread-2
...
```

El orden de procesamiento de los items no se considera determinista cuando se utiliza ejecución paralela.

---

# Pruebas de rendimiento

Para evitar modificar simultáneamente varias variables, las pruebas se realizaron en dos etapas.

## Comparación de hilos

Se mantuvo:

```text
chunkSize = 5
```

y se modificó únicamente la cantidad de hilos.

Resultados observados:

| Hilos | Chunk | Duración |
|---:|---:|---:|
| 1 | 5 | 567.333 ms |
| 2 | 5 | 635.414 ms |
| 3 | 5 | 584.033 ms |
| 4 | 5 | **566.483 ms** |

Dentro del escenario evaluado, `4` hilos presentó el menor tiempo observado.

La diferencia frente a un único hilo fue pequeña debido al reducido volumen del archivo de prueba, por lo que los resultados no implican escalamiento lineal.

---

## Comparación de chunks

Posteriormente se mantuvo:

```text
threads = 4
```

y se modificó únicamente el tamaño del chunk.

| Hilos | Chunk | Duración |
|---:|---:|---:|
| 4 | 1 | 598.638 ms |
| 4 | 2 | 644.882 ms |
| 4 | 5 | 1073.013 ms |
| 4 | 10 | **565.356 ms** |

La configuración con mejor tiempo observado dentro del escenario evaluado fue:

```properties
app.batch.threads=4
app.batch.chunk-size=10
```

Estos valores se dejaron como configuración predeterminada final del proyecto.

Los resultados corresponden al dataset académico utilizado y no representan una garantía de rendimiento para volúmenes o infraestructuras diferentes.

---

# Tolerancia a fallos

Los Steps principales utilizan las capacidades fault-tolerant de Spring Batch para evitar que determinados errores provoquen innecesariamente el fallo completo del proceso.

La solución contempla:

```text
errores recuperables
        ↓
retry

registros inválidos
        ↓
skip
        ↓
auditoría
```

---

## Skip y registros rechazados

Los registros descartados por errores controlados se almacenan en:

```text
registros_rechazados
```

Se registra información como:

- Job.
- Step.
- Fase.
- Contenido original.
- Tipo de error.
- Mensaje.
- JobInstance.
- Fecha del error.

Un caso probado corresponde a un movimiento anual con monto igual a cero:

```text
cuentaId = 107
monto = 0
```

El registro genera:

```text
ReglaNegocioException
```

queda auditado como rechazo y el resto del Job continúa hasta finalizar correctamente.

---

# Política de retry

La política de reintento se encuentra centralizada en:

```text
BatchRetryConfig
```

Configuración predeterminada:

```properties
app.batch.retry-max-retries=3
app.batch.retry-delay-ms=500
```

Está orientada a errores transitorios o recuperables de acceso a datos.

El objetivo es permitir que una operación susceptible de recuperación sea ejecutada nuevamente sin finalizar inmediatamente todo el Job.

---

## Prueba controlada de retry

Para demostrar la política de retry de manera reproducible se incorporó una inyección de fallo controlada en `TransaccionWriter`.

La propiedad:

```properties
app.batch.retry-demo-failures=0
```

permanece desactivada durante la ejecución normal.

Para la prueba de resiliencia se utilizó temporalmente:

```text
--app.batch.retry-demo-failures=1
```

provocando un fallo transitorio antes de persistir el chunk.

El comportamiento observado fue:

```text
FALLO_TRANSITORIO
        ↓
RETRY
        ↓
RECUPERADO
        ↓
procesamiento continúa
        ↓
Job COMPLETED
```

La ejecución de evidencia se realizó con:

```bash
./mvnw spring-boot:run \
  -Dspring-boot.run.arguments="--app.batch.job=transaccionJob --app.batch.run-id=7001 --app.batch.threads=4 --app.batch.chunk-size=10 --app.batch.retry-max-retries=3 --app.batch.retry-delay-ms=500 --app.batch.retry-demo-failures=1"
```

Los logs mostraron:

```text
[BATCH-RETRY-DEMO] ACTIVADO
[BATCH-RETRY-DEMO] FALLO_TRANSITORIO
[BATCH-RETRY-DEMO] RECUPERADO
[BATCH] Estado final: COMPLETED
```

Después de la recuperación se verificaron nuevamente los 10 registros de entrada:

```text
CORREGIDO  = 1
DUPLICADO  = 1
PROCESADO  = 7
RECHAZADO  = 1
TOTAL      = 10
```

Por tanto, la prueba comprobó recuperación automática y consistencia del resultado posterior al reintento.

---

# Persistencia de Spring Batch

La infraestructura utiliza un `JobRepository` JDBC persistente en PostgreSQL.

Esto permite mantener metadata relacionada con:

- Instancias de Jobs.
- Ejecuciones.
- Parámetros.
- Steps.
- Estados de ejecución.
- Contextos.

Las principales tablas son:

```text
BATCH_JOB_INSTANCE
BATCH_JOB_EXECUTION
BATCH_JOB_EXECUTION_PARAMS
BATCH_JOB_EXECUTION_CONTEXT
BATCH_STEP_EXECUTION
BATCH_STEP_EXECUTION_CONTEXT
```

El esquema se encuentra en:

```text
src/main/resources/db/schema-spring-batch-postgresql.sql
```

---

# Inicialización del esquema

La inicialización de las tablas internas de Spring Batch se realiza automáticamente mediante:

```properties
spring.sql.init.mode=always
spring.sql.init.schema-locations=classpath:db/schema-spring-batch-postgresql.sql
```

El script utiliza creación idempotente, permitiendo iniciar nuevamente la aplicación sin intentar recrear de forma destructiva los objetos ya existentes.

Por esta razón **no es necesario ejecutar manualmente el script SQL** antes de cada ejecución.

Las tablas del dominio son gestionadas durante el desarrollo mediante:

```properties
spring.jpa.hibernate.ddl-auto=update
```

---

# PostgreSQL con Docker

Levantar la base de datos:

```bash
docker compose up -d
```

Comprobar estado:

```bash
docker compose ps
```

Configuración predeterminada:

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

# Compilación

En Linux/macOS:

```bash
chmod +x mvnw
./mvnw clean compile
```

La compilación esperada debe terminar con:

```text
BUILD SUCCESS
```

Para ejecutar las pruebas disponibles:

```bash
./mvnw clean test
```

---

# Ejecución controlada de Jobs

Spring Boot no lanza automáticamente todos los Jobs:

```properties
spring.batch.job.enabled=false
```

`ControlledJobRunner` permite seleccionar explícitamente qué Job ejecutar.

Cada ejecución utiliza:

```text
app.batch.job
app.batch.run-id
```

El `run-id` debe cambiarse cuando se desea crear una nueva ejecución identificable.

---

## Transacciones

```bash
./mvnw spring-boot:run \
  -Dspring-boot.run.arguments="--app.batch.job=transaccionJob --app.batch.run-id=1001"
```

## Intereses

```bash
./mvnw spring-boot:run \
  -Dspring-boot.run.arguments="--app.batch.job=cuentaInteresJob --app.batch.run-id=1101"
```

## Estados anuales

```bash
./mvnw spring-boot:run \
  -Dspring-boot.run.arguments="--app.batch.job=estadoCuentaAnualJob --app.batch.run-id=1201"
```

Si no se indican valores específicos para hilos, chunk o retry, se utilizan:

```text
threads          = 4
queue-capacity   = 20
chunk-size       = 10
retry-max-retries = 3
retry-delay-ms   = 500
retry-demo       = 0
```

---

# Consulta de resultados

## Tablas disponibles

```bash
docker compose exec postgres \
  psql -P pager=off -U bancoxyz -d bancoxyz \
  -c '\dt'
```

## Transacciones

```bash
docker compose exec postgres \
  psql -P pager=off -U bancoxyz -d bancoxyz \
  -c 'SELECT * FROM transacciones_procesadas ORDER BY id;'
```

## Resumen diario

```bash
docker compose exec postgres \
  psql -P pager=off -U bancoxyz -d bancoxyz \
  -c 'SELECT * FROM resumen_transacciones_diarias ORDER BY fecha;'
```

## Intereses

```bash
docker compose exec postgres \
  psql -P pager=off -U bancoxyz -d bancoxyz \
  -c 'SELECT * FROM cuentas_intereses ORDER BY cuenta_id;'
```

## Estados anuales

```bash
docker compose exec postgres \
  psql -P pager=off -U bancoxyz -d bancoxyz \
  -c 'SELECT * FROM estados_cuenta_anuales ORDER BY cuenta_id, anio;'
```

## Registros rechazados

```bash
docker compose exec postgres \
  psql -P pager=off -x -U bancoxyz -d bancoxyz \
  -c 'SELECT * FROM registros_rechazados ORDER BY id;'
```

## Historial de Jobs

```bash
docker compose exec postgres \
  psql -P pager=off -U bancoxyz -d bancoxyz \
  -c "
SELECT
    ji.job_name,
    je.job_execution_id,
    je.status,
    je.start_time,
    je.end_time,
    je.exit_code
FROM batch_job_execution je
JOIN batch_job_instance ji
    ON ji.job_instance_id = je.job_instance_id
ORDER BY je.job_execution_id;
"
```

---

# Evidencias de Semana 3

Durante la evaluación se generaron evidencias correspondientes a:

- Compilación limpia con `BUILD SUCCESS`.
- PostgreSQL ejecutándose en estado `healthy`.
- Creación de tablas del dominio y tablas internas de Spring Batch.
- Ejecución completa de `transaccionJob`.
- Detección y persistencia de transacciones duplicadas.
- Generación del resumen diario.
- Ejecución completa de `cuentaInteresJob`.
- Cálculo y persistencia de intereses.
- Ejecución completa de `estadoCuentaAnualJob`.
- Consolidación de movimientos anuales.
- Registro de errores de negocio mediante skip.
- Persistencia del historial de Jobs.
- Procesamiento mediante múltiples hilos.
- Benchmark de 1, 2, 3 y 4 hilos.
- Benchmark de chunks 1, 2, 5 y 10.
- Selección de la configuración con mejor tiempo observado.
- Fallo transitorio controlado.
- Recuperación mediante retry.
- Finalización `COMPLETED` después del retry.
- Verificación de consistencia en PostgreSQL después de la recuperación.

Los logs utilizados como respaldo técnico se encuentran en:

```text
Evidencias_S3/logs/
```

La evidencia visual correspondiente se entrega en el documento PDF de evidencias de Semana 3.

---

# Pruebas realizadas

Durante el desarrollo se verificaron:

- Ejecución correcta de los tres Jobs.
- Persistencia de metadata de Spring Batch.
- Persistencia de resultados en PostgreSQL.
- Reejecución controlada.
- Idempotencia funcional.
- Reconciliación de registros.
- Desactivación de registros ausentes.
- Reactivación de registros que reaparecen.
- Normalización de débitos negativos.
- Detección de transacciones duplicadas.
- Exclusión de duplicados de los cálculos financieros.
- Cálculo mensual de intereses.
- Consolidación anual.
- Manejo de reglas de negocio.
- Skip de registros inválidos.
- Registro de errores.
- Ejecución multihilo.
- Comparación de parámetros de concurrencia.
- Comparación de tamaños de chunk.
- Retry ante fallos transitorios.
- Recuperación automática.
- Conservación de resultados después de un retry.

---

# Consideraciones para producción

Esta implementación corresponde a un entorno académico y de desarrollo.

Para un entorno productivo se recomienda:

- Utilizar variables de entorno o un gestor de secretos para credenciales.
- Utilizar migraciones versionadas mediante Flyway o Liquibase.
- Reemplazar `spring.jpa.hibernate.ddl-auto=update` por una estrategia de migraciones controlada.
- Implementar métricas y observabilidad centralizada.
- Ajustar cantidad de hilos y tamaño de chunk utilizando carga representativa del entorno real.
- Ajustar límites, excepciones y tiempos de retry según métricas operacionales.
- Incorporar alertas para ejecuciones fallidas o excesivamente lentas.
- Aumentar la cobertura de pruebas automatizadas.
- Utilizar infraestructura administrada para PostgreSQL cuando corresponda.
- Aplicar principio de mínimo privilegio a credenciales y accesos.
- Mantener deshabilitado el mecanismo de fallo controlado (`app.batch.retry-demo-failures=0`) fuera de pruebas específicas.

---

# Autoría

**Autora:** `[Natalia Alvarado]`

Proyecto individual desarrollado para la asignatura **Desarrollo Backend III**.

Implementación de modernización y optimización de procesos legacy bancarios mediante Spring Batch.
