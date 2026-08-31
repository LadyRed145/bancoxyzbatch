# Banco XYZ Batch

Proyecto de migración y modernización de procesos batch bancarios desarrollado con **Spring Boot**, **Spring Batch** y **PostgreSQL**.

El sistema procesa archivos CSV provenientes de procesos legacy del Banco XYZ y ejecuta tres procesos principales:

- Procesamiento diario de transacciones.
- Cálculo mensual de intereses.
- Generación de estados de cuenta anuales.

La solución incorpora:

- Lectura de archivos CSV.
- Transformación y normalización de datos.
- Validaciones mediante `ItemProcessor`.
- Persistencia relacional en PostgreSQL.
- Manejo controlado de registros inválidos.
- Fault tolerance mediante `skip`.
- Política de reintentos mediante `retry`.
- Registro persistente de errores.
- Reconciliación e idempotencia.
- Procesamiento paralelo mediante `TaskExecutor`.
- Medición de rendimiento.
- Benchmarks comparativos de hilos y tamaños de chunk.
- Persistencia JDBC de metadata de Spring Batch.

---

## Tecnologías utilizadas

- Java 21
- Spring Boot 4.1.1
- Spring Batch 6
- Spring Data JPA
- Hibernate
- PostgreSQL 17
- Maven Wrapper
- Docker
- Docker Compose
- Lombok
- Jakarta Validation
- Git
- GitHub

---

## Arquitectura general

Los procesos principales siguen el modelo estándar de Spring Batch:

```text
CSV
 │
 ▼
ItemReader
 │
 ▼
ItemProcessor
 │
 ▼
ItemWriter
 │
 ▼
PostgreSQL
```

Los Jobs incorporan además Steps complementarios para:

- Reconciliación de datos.
- Detección de duplicados.
- Generación de resúmenes.
- Persistencia de registros rechazados.
- Mantenimiento del estado activo/inactivo.
- Trazabilidad mediante `JobInstance`.

La metadata de ejecución de Spring Batch se persiste mediante un `JobRepository` JDBC en PostgreSQL.

---

# Estructura principal del proyecto

```text
src/main/java/cl/duoc/bancoxyzbatch/
│
├── BancoxyzbatchApplication.java
│
├── config/
│   ├── BatchInfrastructureConfig.java
│   ├── BatchRetryConfig.java
│   ├── BatchRunContext.java
│   ├── BatchTaskExecutorConfig.java
│   ├── ControlledJobRunner.java
│   ├── CuentaInteresReaderConfig.java
│   ├── MovimientoAnualReaderConfig.java
│   └── TransaccionReaderConfig.java
│
├── exception/
│   └── ReglaNegocioException.java
│
├── job/
│   ├── CuentaInteresJobConfig.java
│   ├── EstadoCuentaAnualJobConfig.java
│   └── TransaccionJobConfig.java
│
├── listener/
│   └── RegistroRechazadoSkipListener.java
│
├── model/
│   ├── CuentaInteres.java
│   ├── CuentaInteresProcesada.java
│   ├── EstadoCuentaAnual.java
│   ├── MovimientoAnual.java
│   ├── RegistroRechazado.java
│   ├── ResumenTransaccionDiaria.java
│   ├── Transaccion.java
│   └── TransaccionProcesada.java
│
├── processor/
│   ├── CuentaInteresProcessor.java
│   ├── MovimientoAnualProcessor.java
│   └── TransaccionProcessor.java
│
├── repository/
│
├── tasklet/
│   ├── CuentaInteresReconciliationTasklet.java
│   ├── EstadoCuentaAnualReconciliationTasklet.java
│   ├── ResumenTransaccionDiariaTasklet.java
│   ├── TransaccionDuplicadosTasklet.java
│   └── TransaccionReconciliationTasklet.java
│
├── util/
│   └── CsvValueParser.java
│
└── writer/
    ├── CuentaInteresWriter.java
    ├── EstadoCuentaAnualWriter.java
    └── TransaccionWriter.java
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

Cada dataset utilizado en la evaluación de Semana 3 contiene **1000 registros de datos**, además de su encabezado.

---

# Lectura robusta de CSV

Los tres Readers utilizan `FlatFileItemReader`.

Para permitir procesamiento concurrente de forma segura, los Readers correspondientes a Jobs paralelos se protegen mediante:

```text
SynchronizedItemStreamReader
```

La conversión de datos se centraliza mediante:

```text
CsvValueParser
```

Esta utilidad permite convertir de forma controlada:

- `String`
- `Long`
- `Integer`
- `BigDecimal`
- `LocalDate`

Las fechas válidas soportadas incluyen:

```text
yyyy-MM-dd
dd-MM-yyyy
dd/MM/yyyy
yyyy/MM/dd
```

Los valores vacíos o inválidos son transformados a `null`, permitiendo que las reglas de negocio sean evaluadas posteriormente por los `ItemProcessor`.

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

El `TransaccionProcessor` valida:

- Identificador.
- Fecha.
- Monto.
- Tipo de transacción.
- Monto distinto de cero.
- Tipo válido `debito` o `credito`.

Cuando un registro incumple una regla de negocio se genera:

```text
ReglaNegocioException
```

El registro es omitido de manera controlada por Spring Batch y almacenado para trazabilidad mediante el mecanismo de registros rechazados.

### Normalización

Los tipos son normalizados a minúsculas.

Los montos de créditos y débitos son convertidos a su valor absoluto para mantener una representación consistente.

Cuando un monto requiere corrección, el registro queda identificado como:

```text
CORREGIDO
```

Los registros válidos sin modificación quedan como:

```text
PROCESADO
```

### Detección de duplicados

El Job incorpora:

```text
transaccionDuplicadosStep
```

Se consideran duplicados funcionales los registros que presentan simultáneamente:

```text
misma fecha
+
mismo monto
+
mismo tipo
```

aunque posean identificadores diferentes.

La primera transacción se conserva y las posteriores quedan marcadas como:

```text
DUPLICADO
```

La ejecución final sobre el dataset actual detectó:

```text
15 duplicados
```

### Resumen diario

El Job incorpora:

```text
resumenTransaccionDiariaStep
```

que genera información consolidada en:

```text
resumen_transacciones_diarias
```

Por cada fecha se calcula:

- Cantidad de transacciones válidas.
- Total de créditos.
- Total de débitos.
- Saldo neto.

La fórmula utilizada es:

```text
saldo_neto = total_creditos - total_debitos
```

Los registros rechazados o duplicados no son considerados dentro de los totales financieros.

### Escalamiento

Este Job utiliza ejecución paralela mediante:

```text
ThreadPoolTaskExecutor
```

Configuración final:

```text
threads = 3
chunk-size = 10
queue-capacity = 20
```

---

## 2. cuentaInteresJob

Procesa el cálculo mensual de intereses.

Archivo:

```text
src/main/resources/data/intereses.csv
```

Formato:

```text
cuenta_id,nombre,saldo,edad,tipo
```

### Tipos válidos

```text
ahorro
prestamo
```

### Tasas utilizadas

Para el caso académico:

```text
ahorro    = 1%
prestamo  = 2%
```

### Cálculo

```text
interes = saldo × tasa
saldo_final = saldo + interes
```

Los resultados monetarios se manejan mediante `BigDecimal`.

### Validaciones

Se valida:

- `cuenta_id`.
- Saldo.
- Saldo no negativo.
- Tipo de cuenta soportado.

Un saldo igual a cero genera:

```text
SIN_INTERES
```

Los registros válidos con cálculo quedan:

```text
PROCESADO
```

Los tipos no admitidos generan una `ReglaNegocioException` y son registrados como descartes controlados.

### Ejecución secuencial intencional

Este Job se ejecuta de manera **secuencial**.

La decisión es intencional debido a que el archivo contiene múltiples registros asociados al mismo:

```text
cuenta_id
```

y la entidad persistida utiliza dicho identificador como clave funcional.

Ejecutar concurrentemente actualizaciones sobre la misma cuenta introduciría condiciones de carrera y resultados no deterministas.

Por esta razón:

```text
cuentaInteresJob
mode = SECUENCIAL
threads = 1
```

mientras que los otros Jobs mantienen procesamiento paralelo.

---

## 3. estadoCuentaAnualJob

Procesa movimientos bancarios y genera un estado consolidado por cuenta y año.

Archivo:

```text
src/main/resources/data/cuentas_anuales.csv
```

Formato:

```text
cuenta_id,fecha,transaccion,monto,descripcion
```

### Movimientos válidos

```text
deposito
retiro
compra
```

El procesador elimina diferencias de mayúsculas/minúsculas y acentos para normalizar los tipos.

### Normalización monetaria

Los depósitos quedan representados como valores positivos.

Los retiros y compras se representan como valores negativos.

El resultado consolidado se persiste en:

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

Existe una restricción funcional única por:

```text
cuenta_id + anio
```

para impedir estados anuales duplicados.

### Escalamiento

El procesamiento principal utiliza ejecución paralela:

```text
mode = PARALELO
threads = 3
chunk-size = 10
```

---

# Tolerancia a fallos

Los tres Jobs utilizan las capacidades de fault tolerance de Spring Batch.

Los Steps principales implementan:

```text
faultTolerant()
```

junto con políticas de:

```text
skip
retry
```

---

## Skip

El límite configurado es:

```properties
app.batch.skip-limit=750
```

Se permite omitir de forma controlada:

```text
FlatFileParseException
ReglaNegocioException
```

Esto permite continuar una ejecución cuando existen registros puntualmente inválidos, manteniendo trazabilidad de los errores sin detener inmediatamente el Job completo.

El límite impide aceptar silenciosamente un archivo completamente corrupto.

---

# Registro de errores

Los registros descartados se almacenan en:

```text
registros_rechazados
```

Mediante:

```text
RegistroRechazadoSkipListener
```

se registra información asociada al error, incluyendo:

- Job.
- Step.
- Fase.
- Registro involucrado.
- Tipo de excepción.
- Mensaje.
- `JobInstance`.
- Fecha del error.

Las fases posibles incluyen:

```text
READ
PROCESS
WRITE
```

Esto permite mantener trazabilidad de los registros que no pudieron incorporarse al resultado final.

---

# Política de Retry

El proyecto implementa una política de reintentos para errores transitorios mediante:

```text
BatchRetryConfig
```

Configuración:

```properties
app.batch.retry-max-retries=3
app.batch.retry-delay-ms=500
```

La política permite volver a intentar operaciones consideradas temporalmente recuperables antes de declarar el Step como fallido.

---

## Prueba controlada de Retry

Para demostrar experimentalmente la recuperación se incorporó:

```properties
app.batch.retry-demo-failures=0
```

El valor debe mantenerse en:

```text
0
```

durante una ejecución normal.

Para validar la política puede ejecutarse:

```bash
java -jar target/bancoxyzbatch-0.0.1-SNAPSHOT.jar \
    --app.batch.job=transaccionJob \
    --app.batch.run-id=5001 \
    --app.batch.retry-demo-failures=1
```

Durante la prueba realizada se obtuvo la secuencia:

```text
FALLO_TRANSITORIO
RECUPERADO
procesamiento continúa
Estado final: COMPLETED
```

La prueba confirmó que el Job pudo recuperarse del fallo transitorio simulado y finalizar correctamente.

---

# Escalamiento y procesamiento paralelo

Los Jobs que pueden ejecutarse concurrentemente utilizan:

```text
ThreadPoolTaskExecutor
```

El executor permite configurar:

```properties
app.batch.threads
app.batch.queue-capacity
```

Los hilos utilizan el prefijo:

```text
batch-thread-
```

permitiendo visualizar en logs qué hilo procesa cada elemento.

Además, los threads son configurados como daemon para permitir el cierre correcto de la JVM después de finalizar una ejecución batch.

---

# Benchmark de rendimiento

Para seleccionar una configuración adecuada se realizaron pruebas controladas sobre el dataset actual.

Cada combinación válida fue ejecutada **3 veces** utilizando una base PostgreSQL recreada entre ejecuciones para evitar contaminación entre mediciones.

La duración se midió directamente alrededor de la ejecución del Job mediante:

```text
System.nanoTime()
```

---

## Comparación de cantidad de hilos

Se utilizó:

```text
chunk-size = 10
```

y se compararon:

| Hilos | Promedio |
|---:|---:|
| 1 | 7931.971 ms |
| 2 | 5465.317 ms |
| **3** | **4883.985 ms** |
| 4 | 5373.557 ms |

La configuración de **3 hilos** presentó el mejor tiempo promedio.

Respecto a un solo hilo, el tiempo medio disminuyó aproximadamente un:

```text
38.4 %
```

Aumentar de 3 a 4 hilos no produjo una mejora adicional y aumentó el tiempo promedio debido al overhead de concurrencia.

Por esta razón se seleccionó:

```text
threads = 3
```

---

## Comparación de tamaños de chunk

Con:

```text
threads = 3
```

se evaluaron:

| Chunk | Resultado | Promedio |
|---:|---|---:|
| 5 | COMPLETED | 6519.185 ms |
| **10** | **COMPLETED** | **5865.691 ms** |
| 25 | FAILED 3/3 | N/A |
| 50 | FAILED 3/3 | N/A |

`chunk-size=10` fue aproximadamente un **10 % más rápido** que `chunk-size=5`.

Los tamaños:

```text
25
50
```

provocaron saturación del `TaskExecutor`.

El error observado fue:

```text
TaskRejectedException
RejectedExecutionException
```

con:

```text
pool size = 3
active threads = 3
queued tasks = 20
```

Los tiempos de las ejecuciones fallidas no se consideran resultados válidos de rendimiento debido a que el dataset no terminó de procesarse.

---

# Configuración óptima seleccionada

La configuración final del proyecto es:

```properties
app.batch.threads=3
app.batch.queue-capacity=20
app.batch.chunk-size=10
```

Esta configuración fue seleccionada mediante comparación experimental considerando tanto:

```text
rendimiento
+
estabilidad
```

---

# Reconciliación e idempotencia

Los tres procesos principales incorporan mecanismos de reconciliación.

Cada registro persistido mantiene información como:

```text
activo
ultima_instancia_id
```

Cuando se procesa una nueva ejecución, los registros presentes son asociados a la nueva `JobInstance`.

Los registros existentes que ya no aparecen en el archivo actual son conservados históricamente y pueden quedar:

```text
activo = false
```

Si posteriormente reaparecen, pueden volver a:

```text
activo = true
```

Este mecanismo permite reejecutar Jobs sin eliminar información histórica ni generar duplicación funcional innecesaria.

---

# Spring Batch JDBC

La infraestructura de Spring Batch utiliza persistencia JDBC.

El esquema PostgreSQL se encuentra en:

```text
src/main/resources/db/schema-spring-batch-postgresql.sql
```

Las tablas principales de metadata incluyen:

```text
BATCH_JOB_INSTANCE
BATCH_JOB_EXECUTION
BATCH_JOB_EXECUTION_PARAMS
BATCH_JOB_EXECUTION_CONTEXT
BATCH_STEP_EXECUTION
BATCH_STEP_EXECUTION_CONTEXT
```

Estas tablas permiten consultar:

- JobInstances.
- JobExecutions.
- Estados.
- Parámetros.
- Métricas de Steps.
- Conteos de lectura.
- Conteos de escritura.
- Skips.
- Commits.
- Rollbacks.

---

# Base de datos PostgreSQL

PostgreSQL puede iniciarse mediante Docker Compose:

```bash
docker compose up -d
```

Verificar el contenedor:

```bash
docker compose ps
```

Configuración predeterminada:

```text
Base de datos: bancoxyz
Usuario:       bancoxyz
Password:      bancoxyz123
Puerto:        5432
```

También pueden utilizarse variables de entorno:

```text
DB_URL
DB_USER
DB_PASSWORD
```

Ejemplo:

```bash
env DB_URL="jdbc:postgresql://localhost:5432/bancoxyz" \
    java -jar target/bancoxyzbatch-0.0.1-SNAPSHOT.jar \
    --app.batch.job=transaccionJob \
    --app.batch.run-id=1
```

---

# Inicialización de Spring Batch

El proyecto configura:

```properties
spring.sql.init.mode=always
spring.sql.init.schema-locations=classpath:db/schema-spring-batch-postgresql.sql
```

El script utilizado es idempotente, por lo que la infraestructura requerida por Spring Batch puede inicializarse sobre una base nueva sin recrear manualmente las tablas en cada ejecución.

Las tablas correspondientes al dominio son gestionadas durante el desarrollo mediante:

```properties
spring.jpa.hibernate.ddl-auto=update
```

---

# Configuración principal

La configuración definitiva incluye:

```properties
spring.batch.job.enabled=false

app.batch.threads=3
app.batch.queue-capacity=20
app.batch.chunk-size=10

app.batch.skip-limit=750

app.batch.retry-max-retries=3
app.batch.retry-delay-ms=500

app.batch.retry-demo-failures=0
```

`ControlledJobRunner` determina explícitamente qué Job debe ejecutarse.

---

# Compilación

Compilar:

```bash
./mvnw clean compile
```

Generar el JAR:

```bash
./mvnw clean package -DskipTests
```

La compilación final de Semana 3 fue validada correctamente:

```text
BUILD SUCCESS
```

El proyecto contiene actualmente:

```text
39 archivos fuente Java compilados
```

---

# Ejecución de Jobs

Cada ejecución requiere:

```text
app.batch.job
app.batch.run-id
```

El `run-id` debe cambiar para crear una nueva ejecución controlada.

Primero generar el JAR:

```bash
./mvnw clean package -DskipTests
```

---

## Ejecutar transaccionJob

```bash
java -jar target/bancoxyzbatch-0.0.1-SNAPSHOT.jar \
    --app.batch.job=transaccionJob \
    --app.batch.run-id=1
```

---

## Ejecutar cuentaInteresJob

```bash
java -jar target/bancoxyzbatch-0.0.1-SNAPSHOT.jar \
    --app.batch.job=cuentaInteresJob \
    --app.batch.run-id=2
```

---

## Ejecutar estadoCuentaAnualJob

```bash
java -jar target/bancoxyzbatch-0.0.1-SNAPSHOT.jar \
    --app.batch.job=estadoCuentaAnualJob \
    --app.batch.run-id=3
```

---

# Validación final de Semana 3

La versión definitiva se ejecutó contra una base PostgreSQL limpia utilizando los tres Jobs.

Resultados:

| Job | Modo | Hilos | Chunk | Estado |
|---|---|---:|---:|---|
| `transaccionJob` | PARALELO | 3 | 10 | COMPLETED |
| `cuentaInteresJob` | SECUENCIAL | 1 | 10 | COMPLETED |
| `estadoCuentaAnualJob` | PARALELO | 3 | 10 | COMPLETED |

---

## Métricas de Steps principales

### transaccionStep

```text
read_count         = 1000
write_count        = 482
process_skip_count = 518
read_skip_count    = 0
write_skip_count   = 0
commit_count       = 100
rollback_count     = 0
```

Verificación:

```text
482 + 518 = 1000
```

---

### cuentaInteresStep

```text
read_count         = 1000
write_count        = 353
process_skip_count = 647
read_skip_count    = 0
write_skip_count   = 0
commit_count       = 100
rollback_count     = 0
```

Verificación:

```text
353 + 647 = 1000
```

---

### estadoCuentaAnualStep

```text
read_count         = 1000
write_count        = 898
process_skip_count = 102
read_skip_count    = 0
write_skip_count   = 0
commit_count       = 100
rollback_count     = 0
```

Verificación:

```text
898 + 102 = 1000
```

Los tres Steps principales procesaron la totalidad de los registros disponibles, ya sea mediante escritura válida o descarte controlado.

---

# Persistencia final

Luego de ejecutar los tres Jobs sobre la base final se obtuvieron:

| Tabla | Registros |
|---|---:|
| `transacciones_procesadas` | 482 |
| `cuentas_intereses` | 50 |
| `estados_cuenta_anuales` | 20 |

La diferencia entre el número de elementos escritos por los Steps y el número final de filas en algunas tablas se debe a la consolidación/actualización de entidades que comparten claves funcionales.

Por ejemplo, múltiples registros del archivo de intereses corresponden a las mismas cuentas.

---

# Consultas de verificación

Ingresar a PostgreSQL:

```bash
docker compose exec postgres \
    psql -U bancoxyz -d bancoxyz
```

---

## Transacciones

```sql
SELECT *
FROM transacciones_procesadas
ORDER BY id;
```

---

## Resumen diario

```sql
SELECT *
FROM resumen_transacciones_diarias
ORDER BY fecha;
```

---

## Intereses

```sql
SELECT *
FROM cuentas_intereses
ORDER BY cuenta_id;
```

---

## Estados anuales

```sql
SELECT *
FROM estados_cuenta_anuales
ORDER BY cuenta_id, anio;
```

---

## Registros rechazados

```sql
SELECT *
FROM registros_rechazados
ORDER BY id;
```

---

## Historial de Jobs

```sql
SELECT
    je.job_execution_id AS ejecucion,
    ji.job_name AS job,
    je.status AS estado,
    je.exit_code AS salida,
    je.start_time AS inicio,
    je.end_time AS fin
FROM batch_job_execution je
JOIN batch_job_instance ji
    ON ji.job_instance_id = je.job_instance_id
ORDER BY je.job_execution_id;
```

---

## Métricas de Steps

```sql
SELECT
    se.job_execution_id AS ejecucion,
    se.step_name AS step,
    se.status AS estado,
    se.read_count AS leidos,
    se.write_count AS escritos,
    se.read_skip_count AS skip_lectura,
    se.process_skip_count AS skip_proceso,
    se.write_skip_count AS skip_escritura,
    se.commit_count AS commits,
    se.rollback_count AS rollbacks
FROM batch_step_execution se
ORDER BY
    se.job_execution_id,
    se.step_execution_id;
```

---

# Scripts de benchmark

Para documentar las pruebas de optimización se utilizaron scripts separados.

## Benchmark de hilos

```text
benchmark_threads.fish
```

Compara:

```text
1
2
3
4
```

hilos con:

```text
chunk-size = 10
```

Los resultados se almacenan en:

```text
benchmarks/threads.csv
```

---

## Benchmark de chunks

```text
benchmark_chunks.fish
```

y:

```text
benchmark_chunks_restantes.fish
```

permiten comparar:

```text
5
10
25
50
```

con:

```text
threads = 3
```

Los resultados se almacenan en:

```text
benchmarks/chunks.csv
benchmarks/chunks_restantes.csv
```

---

## Visualización resumida del benchmark

El script:

```text
mostrar_benchmark.fish
```

presenta en terminal la comparación de rendimiento y la configuración óptima seleccionada.

---

# Evidencias

Las evidencias de Semana 3 incluyen comprobaciones de:

- Compilación exitosa.
- Ejecución de los tres Jobs.
- Estados `COMPLETED`.
- Procesamiento paralelo.
- Ejecución secuencial controlada del Job de intereses.
- Comparación de 1, 2, 3 y 4 hilos.
- Comparación de chunks 5, 10, 25 y 50.
- Selección de configuración óptima.
- Saturación controlada de configuraciones inestables.
- Fault tolerance.
- Conteos de `skip`.
- Política de retry.
- Fallo transitorio simulado.
- Recuperación automática.
- Persistencia final.
- Metadata de Spring Batch.
- Conteos de lectura, escritura, commits y rollbacks.

---

# Pruebas realizadas

Durante el desarrollo se verificaron:

- Ejecución correcta de los tres Jobs.
- Lectura de datasets de 1000 registros.
- Transformación mediante `ItemProcessor`.
- Persistencia en PostgreSQL.
- Reejecución sin duplicación funcional.
- Desactivación de registros ausentes.
- Reactivación de registros que reaparecen.
- Detección de transacciones duplicadas.
- Normalización de montos.
- Exclusión de duplicados del resumen financiero.
- Cálculo mensual de intereses.
- Consolidación anual.
- Manejo de errores de formato.
- Manejo de reglas de negocio.
- Persistencia de registros rechazados.
- Fault tolerance con `skip`.
- Retry ante fallos transitorios.
- Recuperación posterior al fallo.
- Ejecución paralela.
- Comparación experimental de configuraciones.
- Selección de parámetros según rendimiento y estabilidad.
- Compilación Maven sin errores.

---

# Consideraciones de producción

La implementación corresponde a un entorno académico y de desarrollo.

Para un entorno productivo se recomienda:

- Utilizar variables de entorno o un gestor de secretos para credenciales.
- Utilizar migraciones versionadas mediante Flyway o Liquibase.
- Reemplazar `ddl-auto=update` por una estrategia formal de migraciones.
- Implementar monitoreo y métricas centralizadas.
- Integrar logs estructurados.
- Definir políticas de retry específicas según tipo de error.
- Implementar límites de recursos según infraestructura disponible.
- Aumentar la cobertura de pruebas automatizadas.
- Utilizar PostgreSQL administrado o infraestructura de alta disponibilidad.
- Aplicar el principio de mínimo privilegio.
- Proteger los archivos de entrada y datos bancarios.
- Incorporar observabilidad y alertamiento operacional.

---

# Autoría


**Autora:** `[Natalia Alvarado]`

Proyecto desarrollado para la asignatura:

**Desarrollo Backend III**

Caso académico:

**Banco XYZ**

Implementación orientada a modernizar procesos legacy bancarios mediante **Spring Batch**, incorporando procesamiento robusto, tolerancia a fallos, escalamiento, optimización experimental y persistencia relacional.
