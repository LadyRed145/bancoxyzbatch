# Propuesta Técnica — Banco XYZ Batch

## 1. Introducción

Banco XYZ mantiene procesos batch provenientes de un sistema legacy para ejecutar operaciones relacionadas con transacciones, intereses y estados de cuenta.

La presente propuesta técnica plantea la modernización de estos procesos utilizando **Spring Batch**, integrando persistencia relacional mediante **PostgreSQL**, procesamiento de archivos CSV, validaciones, tolerancia a fallos, reintentos, trazabilidad, reconciliación y mecanismos de escalamiento.

La solución fue diseñada para procesar los tres procesos bancarios solicitados:

1. Reporte de transacciones diarias.
2. Cálculo mensual de intereses.
3. Generación de estados de cuenta anuales.

Durante la etapa correspondiente a Semana 3 se incorporaron además mecanismos de optimización, procesamiento paralelo, políticas de retry y pruebas comparativas de rendimiento.

---

# 2. Objetivo general

Modernizar los procesos batch legacy del Banco XYZ mediante una solución basada en Spring Batch que permita procesar información bancaria desde archivos CSV hacia una base de datos relacional, manteniendo consistencia, trazabilidad, tolerancia a errores y capacidad de escalamiento.

---

# 3. Objetivos específicos

- Implementar tres Jobs independientes utilizando Spring Batch.
- Procesar archivos CSV mediante `ItemReader`.
- Aplicar validaciones y transformaciones mediante `ItemProcessor`.
- Persistir resultados utilizando `ItemWriter`.
- Registrar información procesada en PostgreSQL.
- Detectar y controlar registros incorrectos.
- Mantener trazabilidad de registros descartados.
- Aplicar mecanismos de `skip` ante errores recuperables.
- Implementar políticas de `retry` para fallos transitorios.
- Mantener idempotencia entre ejecuciones.
- Implementar procesamiento paralelo donde sea técnicamente seguro.
- Comparar diferentes configuraciones de paralelismo y tamaño de chunk.
- Seleccionar una configuración óptima según rendimiento y estabilidad.
- Registrar metadata de Jobs y Steps mediante el repositorio JDBC de Spring Batch.

---

# 4. Tecnologías seleccionadas

| Tecnología | Uso |
|---|---|
| Java 21 | Lenguaje principal |
| Spring Boot 4.1.1 | Infraestructura de aplicación |
| Spring Batch 6 | Procesamiento batch |
| Spring Data JPA | Persistencia |
| Hibernate | ORM |
| PostgreSQL 17 | Base de datos relacional |
| Maven Wrapper | Gestión de dependencias y compilación |
| Docker Compose | Aprovisionamiento de PostgreSQL |
| Git | Control de versiones |
| GitHub | Repositorio remoto |

---

# 5. Arquitectura propuesta

La solución utiliza la arquitectura estándar de Spring Batch:

```text
                  ┌─────────────────────┐
                  │      Archivo CSV    │
                  └──────────┬──────────┘
                             │
                             ▼
                  ┌─────────────────────┐
                  │     ItemReader      │
                  │ lectura de registros│
                  └──────────┬──────────┘
                             │
                             ▼
                  ┌─────────────────────┐
                  │    ItemProcessor    │
                  │ validación / reglas │
                  └──────────┬──────────┘
                             │
                             ▼
                  ┌─────────────────────┐
                  │     ItemWriter      │
                  │    persistencia     │
                  └──────────┬──────────┘
                             │
                             ▼
                  ┌─────────────────────┐
                  │     PostgreSQL      │
                  └─────────────────────┘
```

Cada proceso se implementa como un Job independiente.

Adicionalmente se utilizan Steps complementarios para tareas de:

- Reconciliación.
- Detección de duplicados.
- Generación de resúmenes.
- Actualización de estados.
- Control de información histórica.

---

# 6. Procesos Batch

## 6.1 Reporte de Transacciones Diarias

Job:

```text
transaccionJob
```

Archivo:

```text
transacciones.csv
```

Formato:

```text
id,fecha,monto,tipo
```

El proceso realiza:

- Lectura de transacciones.
- Validación de identificador.
- Validación de fecha.
- Validación de monto.
- Validación del tipo de movimiento.
- Normalización de créditos y débitos.
- Detección de anomalías.
- Detección de duplicados funcionales.
- Persistencia del resultado.
- Generación de un resumen diario.

Los tipos permitidos son:

```text
debito
credito
```

Los registros inválidos generan una excepción controlada de negocio:

```text
ReglaNegocioException
```

---

## 6.2 Detección de duplicados

Se consideran posibles duplicados las transacciones que coinciden simultáneamente en:

```text
fecha
monto
tipo
```

aunque presenten identificadores diferentes.

Los registros identificados como duplicados quedan marcados con:

```text
DUPLICADO
```

La ejecución final sobre el dataset correspondiente detectó:

```text
15 duplicados
```

Estos registros no son incluidos nuevamente en los cálculos financieros.

---

## 6.3 Resumen de Transacciones Diarias

El Job de transacciones incorpora:

```text
resumenTransaccionDiariaStep
```

El Step genera información consolidada por fecha:

- Cantidad de transacciones.
- Total de créditos.
- Total de débitos.
- Saldo neto.

El cálculo se realiza mediante:

```text
saldo_neto = total_creditos - total_debitos
```

---

# 7. Cálculo Mensual de Intereses

Job:

```text
cuentaInteresJob
```

Archivo:

```text
intereses.csv
```

Formato:

```text
cuenta_id,nombre,saldo,edad,tipo
```

Se consideran los siguientes tipos:

```text
ahorro
prestamo
```

Las tasas utilizadas para el caso académico son:

```text
ahorro   = 1%
prestamo = 2%
```

El interés se calcula mediante:

```text
interes = saldo × tasa
```

Posteriormente:

```text
saldo_final = saldo + interes
```

Los valores monetarios se manejan mediante `BigDecimal`.

Un saldo igual a cero se identifica como:

```text
SIN_INTERES
```

Los tipos no soportados son rechazados mediante las reglas de negocio.

---

# 8. Decisión de ejecución secuencial para intereses

El archivo de intereses contiene múltiples registros relacionados con un mismo:

```text
cuenta_id
```

La entidad de salida utiliza dicha cuenta como identificador funcional.

Procesar concurrentemente varias actualizaciones sobre la misma cuenta podría provocar:

- Condiciones de carrera.
- Sobrescrituras concurrentes.
- Resultados no deterministas.

Por esta razón se decidió mantener:

```text
cuentaInteresJob
mode = SECUENCIAL
threads = 1
```

Esta decisión prioriza la consistencia sobre el paralelismo.

Los Jobs que no presentan esta restricción utilizan procesamiento paralelo.

---

# 9. Estados de Cuenta Anuales

Job:

```text
estadoCuentaAnualJob
```

Archivo:

```text
cuentas_anuales.csv
```

Formato:

```text
cuenta_id,fecha,transaccion,monto,descripcion
```

Los movimientos admitidos son:

```text
deposito
retiro
compra
```

El sistema normaliza:

- Mayúsculas y minúsculas.
- Acentos.
- Signo de los montos.

Los depósitos se representan como valores positivos.

Los retiros y compras se representan como valores negativos.

El estado final consolida:

- Cuenta.
- Año.
- Total de depósitos.
- Total de retiros.
- Total de compras.
- Saldo anual.

Existe una restricción funcional basada en:

```text
cuenta_id + anio
```

para evitar estados duplicados.

---

# 10. Procesamiento robusto de datos

Los datasets utilizados en Semana 3 contienen:

```text
1000 registros por archivo
```

Los Readers utilizan:

```text
FlatFileItemReader
```

y una capa de conversión reutilizable:

```text
CsvValueParser
```

Esta utilidad permite convertir de manera controlada:

- String.
- Long.
- Integer.
- BigDecimal.
- LocalDate.

Para las fechas se aceptan los formatos:

```text
yyyy-MM-dd
dd-MM-yyyy
dd/MM/yyyy
yyyy/MM/dd
```

Los valores que no pueden convertirse son entregados al Processor como datos inválidos para ser gestionados mediante las reglas de negocio.

---

# 11. Manejo de errores

Uno de los objetivos principales de la solución es evitar que un único registro inválido provoque innecesariamente el fallo completo del Job.

Los Steps principales utilizan:

```text
faultTolerant()
```

junto con mecanismos de:

```text
skip
retry
```

---

## 11.1 Política de Skip

El límite configurado es:

```text
app.batch.skip-limit=750
```

Se controlan principalmente:

```text
FlatFileParseException
ReglaNegocioException
```

El objetivo es permitir el procesamiento de archivos legacy que contienen información incorrecta o mal clasificada, manteniendo un límite que evite aceptar silenciosamente un archivo completamente corrupto.

---

# 12. Registro de información rechazada

Los descartes son almacenados en:

```text
registros_rechazados
```

mediante:

```text
RegistroRechazadoSkipListener
```

La información registrada permite identificar:

- Job.
- Step.
- Fase del error.
- Registro.
- Excepción.
- Mensaje.
- JobInstance.
- Fecha.

Las fases contempladas son:

```text
READ
PROCESS
WRITE
```

Esto permite auditar posteriormente los registros que no pudieron incorporarse correctamente al procesamiento.

---

# 13. Política de Retry

La solución incorpora una política de reintentos para errores de naturaleza transitoria.

La configuración es:

```text
app.batch.retry-max-retries=3
app.batch.retry-delay-ms=500
```

La política se centraliza mediante:

```text
BatchRetryConfig
```

De esta manera, una operación temporalmente fallida puede ser reintentada antes de declarar el Step como fallido.

---

# 14. Validación experimental de Retry

Para validar la política se incorporó una simulación controlada:

```text
app.batch.retry-demo-failures
```

Durante la ejecución normal:

```text
app.batch.retry-demo-failures=0
```

Para la prueba se utilizó:

```text
app.batch.retry-demo-failures=1
```

La ejecución produjo:

```text
FALLO_TRANSITORIO
RECUPERADO
procesamiento continúa
Estado final: COMPLETED
```

El resultado demuestra que el Job fue capaz de:

```text
detectar fallo
      ↓
aplicar retry
      ↓
recuperarse
      ↓
continuar procesamiento
      ↓
finalizar COMPLETED
```

---

# 15. Escalamiento mediante procesamiento paralelo

Los Jobs compatibles utilizan:

```text
ThreadPoolTaskExecutor
```

El número de hilos se controla mediante:

```text
app.batch.threads
```

La capacidad de tareas pendientes mediante:

```text
app.batch.queue-capacity
```

y el tamaño de lote mediante:

```text
app.batch.chunk-size
```

Los Readers utilizados en procesamiento concurrente son protegidos mediante:

```text
SynchronizedItemStreamReader
```

para mantener acceso seguro al recurso de entrada.

---

# 16. Estrategia de optimización

No se seleccionó una configuración de paralelismo arbitrariamente.

Se realizaron benchmarks controlados modificando:

1. Cantidad de hilos.
2. Tamaño del chunk.

Cada configuración válida fue ejecutada tres veces.

Para evitar contaminación entre pruebas se recreó una base PostgreSQL independiente antes de cada ejecución.

La duración del Job fue medida mediante:

```text
System.nanoTime()
```

---

# 17. Benchmark de hilos

Se mantuvo:

```text
chunk-size = 10
```

y se evaluaron cuatro configuraciones.

| Hilos | Promedio |
|---:|---:|
| 1 | 7931.971 ms |
| 2 | 5465.317 ms |
| 3 | 4883.985 ms |
| 4 | 5373.557 ms |

La configuración con:

```text
3 hilos
```

obtuvo el menor tiempo promedio.

La reducción aproximada respecto de un único hilo fue de:

```text
38.4 %
```

El uso de cuatro hilos no produjo una mejora adicional.

Esto indica que aumentar el paralelismo más allá del nivel útil introduce overhead asociado a:

- Coordinación de threads.
- Acceso concurrente.
- Transacciones.
- Persistencia.
- Sincronización.

---

# 18. Benchmark de tamaño de Chunk

Una vez seleccionados tres hilos se probaron distintos tamaños de chunk.

| Chunk | Resultado | Promedio |
|---:|---|---:|
| 5 | COMPLETED | 6519.185 ms |
| 10 | COMPLETED | 5865.691 ms |
| 25 | FAILED 3/3 | N/A |
| 50 | FAILED 3/3 | N/A |

Entre las configuraciones estables:

```text
chunk-size = 10
```

presentó el mejor rendimiento.

Fue aproximadamente un:

```text
10 %
```

más rápido que `chunk-size=5`.

---

# 19. Detección de configuraciones inestables

Los chunks:

```text
25
50
```

provocaron saturación del executor.

Se observó:

```text
TaskRejectedException
RejectedExecutionException
```

con un estado equivalente a:

```text
pool size = 3
active threads = 3
queued tasks = 20
```

Esto demostró que incrementar arbitrariamente el tamaño de los lotes puede degradar la estabilidad de la aplicación.

Los tiempos obtenidos en las ejecuciones fallidas no se utilizaron para comparar rendimiento porque el dataset no terminó de procesarse.

---

# 20. Configuración óptima

Después de las pruebas se seleccionó:

```text
app.batch.threads=3
app.batch.chunk-size=10
app.batch.queue-capacity=20
```

La elección considera simultáneamente:

```text
rendimiento
+
estabilidad
```

Esta configuración se utiliza como valor predeterminado de la versión final.

---

# 21. Idempotencia y reconciliación

Los tres Jobs implementan mecanismos de reconciliación.

Cada registro persistido puede mantener:

```text
activo
ultima_instancia_id
```

Al realizar una nueva ejecución:

- Los registros presentes son actualizados.
- Se registra la nueva `JobInstance`.
- Los registros que desaparecen del archivo pueden quedar inactivos.
- Si posteriormente reaparecen pueden reactivarse.

Ejemplo:

```text
activo = false
```

y posteriormente:

```text
activo = true
```

Este mecanismo evita eliminar información histórica y permite reejecutar los procesos sin generar duplicación funcional innecesaria.

---

# 22. Persistencia

Se utiliza PostgreSQL como base relacional.

Las principales tablas del dominio son:

```text
transacciones_procesadas
cuentas_intereses
estados_cuenta_anuales
registros_rechazados
resumen_transacciones_diarias
```

También se utiliza el esquema JDBC de Spring Batch para mantener metadata de ejecución.

---

# 23. Metadata de Spring Batch

El repositorio JDBC permite almacenar:

```text
BATCH_JOB_INSTANCE
BATCH_JOB_EXECUTION
BATCH_JOB_EXECUTION_PARAMS
BATCH_JOB_EXECUTION_CONTEXT
BATCH_STEP_EXECUTION
BATCH_STEP_EXECUTION_CONTEXT
```

Esto permite consultar:

- Jobs ejecutados.
- Estados.
- Tiempos.
- Parámetros.
- Conteos de lectura.
- Conteos de escritura.
- Skips.
- Commits.
- Rollbacks.

---

# 24. Resultados de ejecución final

La versión final fue ejecutada sobre una base limpia.

Los tres Jobs finalizaron correctamente:

| Job | Modo | Hilos | Chunk | Resultado |
|---|---|---:|---:|---|
| `transaccionJob` | PARALELO | 3 | 10 | COMPLETED |
| `cuentaInteresJob` | SECUENCIAL | 1 | 10 | COMPLETED |
| `estadoCuentaAnualJob` | PARALELO | 3 | 10 | COMPLETED |

---

# 25. Métricas de procesamiento

## transaccionStep

```text
Leídos       = 1000
Escritos     = 482
Skip proceso = 518
Rollbacks    = 0
```

Validación:

```text
482 + 518 = 1000
```

---

## cuentaInteresStep

```text
Leídos       = 1000
Escritos     = 353
Skip proceso = 647
Rollbacks    = 0
```

Validación:

```text
353 + 647 = 1000
```

---

## estadoCuentaAnualStep

```text
Leídos       = 1000
Escritos     = 898
Skip proceso = 102
Rollbacks    = 0
```

Validación:

```text
898 + 102 = 1000
```

Los tres procesos contabilizaron la totalidad de sus registros de entrada mediante escritura válida o descarte controlado.

---

# 26. Persistencia final verificada

Luego de ejecutar los tres Jobs se observaron:

| Tabla | Filas persistidas |
|---|---:|
| `transacciones_procesadas` | 482 |
| `cuentas_intereses` | 50 |
| `estados_cuenta_anuales` | 20 |

La cantidad de filas finales puede ser inferior al número de escrituras realizadas debido a actualizaciones y consolidaciones sobre claves funcionales existentes.

Por ejemplo, múltiples entradas del archivo de intereses corresponden a las mismas cuentas.

---

# 27. Seguridad y configuración

La conexión permite configurar:

```text
DB_URL
DB_USER
DB_PASSWORD
```

mediante variables de entorno.

Para el entorno académico existe una configuración local predeterminada mediante Docker Compose.

En un entorno productivo se recomienda:

- Utilizar gestores de secretos.
- No almacenar credenciales reales dentro del repositorio.
- Utilizar usuarios de base de datos con mínimo privilegio.
- Aplicar cifrado de conexiones.
- Restringir acceso a archivos de entrada.

---

# 28. Consideraciones de producción

Para una futura implementación productiva se propone:

- Migraciones mediante Flyway o Liquibase.
- Deshabilitar `ddl-auto=update`.
- Métricas mediante Micrometer.
- Integración con una plataforma de observabilidad.
- Centralización de logs.
- Alertas ante Jobs fallidos.
- Políticas de retry específicas por excepción.
- Configuración dinámica según capacidad de infraestructura.
- Mayor cobertura de pruebas automatizadas.
- Control de acceso a información financiera.
- Backups de PostgreSQL.
- Alta disponibilidad.
- Procesamiento mediante scheduler u orquestador.

---

# 29. Conclusión

La propuesta moderniza los procesos legacy del Banco XYZ utilizando una arquitectura basada en Spring Batch y PostgreSQL.

La solución permite:

```text
leer
↓
validar
↓
transformar
↓
procesar
↓
persistir
↓
auditar
```

los datos provenientes de archivos CSV.

La implementación no solamente incorpora los tres procesos bancarios requeridos, sino que agrega mecanismos de:

- Validación.
- Reconciliación.
- Idempotencia.
- Registro de errores.
- Fault tolerance.
- Skip.
- Retry.
- Recuperación de fallos transitorios.
- Paralelismo.
- Medición de rendimiento.
- Optimización mediante benchmarks.

Las pruebas realizadas permitieron seleccionar empíricamente una configuración de:

```text
3 hilos
chunk-size 10
queue-capacity 20
```

obteniendo un equilibrio adecuado entre rendimiento y estabilidad.

La ejecución final confirmó que los tres Jobs completan correctamente el procesamiento de los datasets y que la información resultante queda registrada tanto en las tablas de negocio como en la metadata de Spring Batch.

---

# Autoría


**Autora:** `[Natalia Alvarado]`

Proyecto desarrollado para la asignatura:

**Desarrollo Backend III**

Caso académico:

**Modernización de procesos batch del Banco XYZ**
