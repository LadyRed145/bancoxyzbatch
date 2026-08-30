# Propuesta Técnica — Banco XYZ Batch

## Optimizando procesos batch para mejorar la resiliencia de procesos

**Asignatura:** Desarrollo Backend III  
**Semana:** 3  
**Autora:** Natalia Alvarado  

---

# 1. Contexto

Banco XYZ mantiene procesos legacy encargados de procesar información financiera mediante archivos CSV.

La modernización propuesta utiliza **Spring Batch** como motor de procesamiento batch, **PostgreSQL** como sistema de persistencia y **Spring Boot** como plataforma de configuración y ejecución.

La solución mantiene tres procesos principales:

1. Procesamiento diario de transacciones.
2. Cálculo mensual de intereses.
3. Generación de estados de cuenta anuales.

Sobre la implementación desarrollada durante las semanas anteriores, en esta etapa se incorporan mecanismos de:

- Procesamiento paralelo.
- Configuración dinámica de hilos y chunks.
- Tolerancia a fallos.
- Reintentos ante fallos transitorios.
- Registro de errores.
- Reconciliación e idempotencia.
- Persistencia de metadata de Spring Batch.
- Medición y comparación de rendimiento.

---

# 2. Objetivo de la propuesta

El objetivo es modernizar los procesos batch del Banco XYZ mediante una arquitectura que permita procesar datos de manera:

- Consistente.
- Trazable.
- Reejecutable.
- Tolerante a fallos.
- Escalable.
- Configurable.
- Persistente.

La propuesta busca evitar que un registro incorrecto o un fallo temporal provoque innecesariamente la pérdida completa de una ejecución.

También se busca determinar una configuración apropiada de paralelismo y tamaño de chunk mediante mediciones realizadas sobre el escenario académico disponible.

---

# 3. Arquitectura propuesta

La solución utiliza la arquitectura estándar de Spring Batch:

```text
Archivo CSV
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

Cada Job se compone de uno o más Steps especializados.

La arquitectura se complementa con:

```text
                  ┌───────────────────────┐
                  │    ControlledJobRunner │
                  └───────────┬───────────┘
                              │
                              ▼
                     Selección del Job
                              │
           ┌──────────────────┼──────────────────┐
           ▼                  ▼                  ▼
 transaccionJob       cuentaInteresJob   estadoCuentaAnualJob
           │                  │                  │
           ▼                  ▼                  ▼
 Reader/Processor/     Reader/Processor/   Reader/Processor/
      Writer                Writer              Writer
           │                  │                  │
           └──────────────────┼──────────────────┘
                              ▼
                         PostgreSQL
                              │
               ┌──────────────┴──────────────┐
               ▼                             ▼
       Datos del negocio              Metadata Batch
```

---

# 4. Diseño de Jobs

## 4.1. `transaccionJob`

Procesa las transacciones diarias y ejecuta el siguiente flujo:

```text
transaccionStep
      ↓
transaccionDuplicadosStep
      ↓
transaccionReconciliationStep
      ↓
resumenTransaccionDiariaStep
```

Responsabilidades principales:

- Lectura del CSV de transacciones.
- Validación de campos.
- Normalización de débitos negativos.
- Persistencia de resultados.
- Detección de duplicados.
- Reconciliación de ejecuciones.
- Generación del resumen financiero diario.

---

## 4.2. `cuentaInteresJob`

Procesa información de cuentas bancarias para calcular intereses mensuales.

Flujo principal:

```text
cuentaInteresStep
      ↓
cuentaInteresReconciliationStep
```

Responsabilidades:

- Validación de cuentas.
- Clasificación según tipo.
- Aplicación de tasas.
- Cálculo del interés.
- Cálculo del saldo final.
- Persistencia.
- Reconciliación.

---

## 4.3. `estadoCuentaAnualJob`

Procesa movimientos bancarios anuales y consolida los resultados por cuenta y año.

Flujo:

```text
estadoCuentaAnualStep
      ↓
estadoCuentaAnualReconciliationStep
```

Responsabilidades:

- Validación de movimientos.
- Normalización de depósitos, retiros y compras.
- Consolidación anual.
- Persistencia del resultado.
- Registro de movimientos rechazados.
- Reconciliación de ejecuciones.

---

# 5. Procesamiento y validación de datos

Las transformaciones principales se implementan mediante `ItemProcessor`.

Esta separación permite mantener las reglas de negocio independientes de la lectura y persistencia.

Entre las validaciones implementadas se encuentran:

- Identificadores obligatorios.
- Fechas válidas.
- Montos válidos.
- Tipos de transacción soportados.
- Tipos de cuenta soportados.
- Rechazo de operaciones con monto cero cuando corresponde.

También se implementan transformaciones controladas.

Por ejemplo, un débito ingresado con monto negativo se normaliza utilizando su valor absoluto y se identifica como:

```text
CORREGIDO
```

Esto permite corregir una anomalía conocida sin perder trazabilidad sobre la transformación aplicada.

---

# 6. Integridad e idempotencia

Una ejecución batch puede repetirse, por lo que la solución debe evitar duplicar funcionalmente los datos.

Para este propósito los registros mantienen información como:

```text
activo
ultima_instancia_id
```

Cada ejecución se relaciona con la `JobInstance` correspondiente.

La reconciliación permite:

- Actualizar los registros presentes.
- Detectar registros ausentes.
- Mantener registros históricos.
- Marcar información ausente como inactiva.
- Reactivar información si vuelve a aparecer.
- Evitar eliminaciones innecesarias.

De esta manera, la reejecución no implica insertar nuevamente toda la información como si fuese nueva.

---

# 7. Detección de duplicados

El procesamiento de transacciones incorpora detección de duplicados funcionales.

Se considera posible duplicado cuando dos registros poseen:

```text
misma fecha
+
mismo monto
+
mismo tipo
```

La primera ocurrencia se conserva y la siguiente se clasifica como:

```text
DUPLICADO
```

El registro no se elimina, ya que su conservación permite mantener trazabilidad y auditoría.

Los duplicados tampoco participan en los cálculos financieros consolidados.

---

# 8. Estrategia de escalamiento

Para esta implementación se seleccionó una estrategia basada en **procesamiento multihilo**.

Se utiliza:

```text
ThreadPoolTaskExecutor
```

con parámetros configurables.

La elección de multithreading se realizó porque el escenario utiliza una única fuente de entrada por proceso y permite introducir concurrencia sin requerir dividir previamente los archivos en particiones independientes.

Los Readers utilizados dentro del procesamiento concurrente se sincronizan mediante:

```text
SynchronizedItemStreamReader
```

con el objetivo de proteger el acceso al stream de entrada.

---

# 9. Parámetros de escalamiento

Los parámetros principales se externalizaron mediante propiedades:

```properties
app.batch.threads=4
app.batch.queue-capacity=20
app.batch.chunk-size=10
```

Esto permite modificar la configuración sin cambiar el código fuente.

Además, los valores pueden sobrescribirse durante la ejecución para realizar pruebas comparativas.

---

# 10. Evaluación de cantidad de hilos

Para comparar el efecto del paralelismo se mantuvo constante:

```text
chunkSize = 5
```

y se modificó únicamente la cantidad de hilos.

Resultados obtenidos:

| Threads | Chunk | Duración observada |
|---:|---:|---:|
| 1 | 5 | 567.333 ms |
| 2 | 5 | 635.414 ms |
| 3 | 5 | 584.033 ms |
| 4 | 5 | **566.483 ms** |

La mejor medición de este conjunto correspondió a:

```text
threads = 4
```

La diferencia entre configuraciones es reducida debido al pequeño volumen del dataset académico.

Por esta razón, los resultados se interpretan únicamente dentro del escenario evaluado y no como una afirmación de escalamiento lineal.

---

# 11. Evaluación del tamaño de chunk

Posteriormente se mantuvo:

```text
threads = 4
```

y se modificó únicamente el tamaño del chunk.

Resultados:

| Threads | Chunk | Duración observada |
|---:|---:|---:|
| 4 | 1 | 598.638 ms |
| 4 | 2 | 644.882 ms |
| 4 | 5 | 1073.013 ms |
| 4 | 10 | **565.356 ms** |

Dentro del escenario evaluado, la mejor medición correspondió a:

```text
threads = 4
chunkSize = 10
```

Por esta razón dichos valores fueron seleccionados como configuración predeterminada final.

---

# 12. Configuración propuesta

La configuración base utilizada después de las pruebas es:

```properties
app.batch.threads=4
app.batch.queue-capacity=20
app.batch.chunk-size=10

app.batch.retry-max-retries=3
app.batch.retry-delay-ms=500
app.batch.retry-demo-failures=0
```

Esta configuración mantiene separados los parámetros de:

```text
Escalamiento
├── threads
├── queue-capacity
└── chunk-size

Resiliencia
├── retry-max-retries
├── retry-delay-ms
└── retry-demo-failures
```

---

# 13. Tolerancia a fallos

La estrategia de resiliencia diferencia principalmente dos clases de situaciones.

## 13.1. Datos inválidos

Cuando un registro presenta un error de negocio controlable, puede ser omitido mediante la política de tolerancia a fallos del Step.

Ejemplo validado:

```text
Movimiento anual
cuentaId = 107
monto = 0
```

El registro genera:

```text
ReglaNegocioException
```

y se almacena en:

```text
registros_rechazados
```

La ejecución puede continuar procesando los demás registros.

---

## 13.2. Fallos transitorios

Determinados errores técnicos pueden ser recuperables, por lo que no resulta conveniente abortar inmediatamente todo el Job.

Para estos escenarios se configuró una política de retry.

Parámetros:

```properties
app.batch.retry-max-retries=3
app.batch.retry-delay-ms=500
```

La política permite repetir una operación antes de considerar definitivo el fallo.

---

# 14. Validación controlada de retry

Para verificar la política de retry se incorporó un mecanismo de prueba controlado.

Propiedad:

```properties
app.batch.retry-demo-failures=0
```

Durante una ejecución normal permanece deshabilitado.

Para la evidencia se utilizó:

```text
app.batch.retry-demo-failures=1
```

El comportamiento observado fue:

```text
Primera invocación del Writer
        │
        ▼
Fallo transitorio simulado
        │
        ▼
Política de retry
        │
        ▼
Nueva invocación
        │
        ▼
Recuperación
        │
        ▼
Persistencia
        │
        ▼
Job COMPLETED
```

La salida registrada confirmó:

```text
[BATCH-RETRY-DEMO] ACTIVADO
[BATCH-RETRY-DEMO] FALLO_TRANSITORIO
[BATCH-RETRY-DEMO] RECUPERADO
[BATCH] Estado final: COMPLETED
```

---

# 15. Verificación de consistencia posterior al retry

Después de provocar y recuperar el fallo se verificó el resultado almacenado en PostgreSQL.

Se obtuvieron:

```text
CORREGIDO = 1
DUPLICADO = 1
PROCESADO = 7
RECHAZADO = 1
```

Total:

```text
10 registros
```

Esto demuestra que la recuperación del fallo transitorio no provocó pérdida de registros en el escenario probado.

Además, la metadata del Step mostró:

```text
read_count     = 10
write_count    = 10
rollback_count = 0
status         = COMPLETED
```

---

# 16. Registro de errores

Los errores de registros individuales se almacenan en:

```text
registros_rechazados
```

La información permite mantener trazabilidad sobre:

- Job.
- Step.
- Fase.
- Tipo de excepción.
- Mensaje.
- Contenido original.
- JobInstance.
- Fecha de registro.

Esta estrategia evita ocultar información problemática y facilita futuras auditorías.

---

# 17. Persistencia de metadata

Spring Batch utiliza un `JobRepository` JDBC sobre PostgreSQL.

Se persisten tablas de infraestructura como:

```text
BATCH_JOB_INSTANCE
BATCH_JOB_EXECUTION
BATCH_JOB_EXECUTION_PARAMS
BATCH_JOB_EXECUTION_CONTEXT
BATCH_STEP_EXECUTION
BATCH_STEP_EXECUTION_CONTEXT
```

Esto permite consultar posteriormente:

- Estado del Job.
- Estado de cada Step.
- Tiempos de ejecución.
- Parámetros utilizados.
- Cantidad de registros leídos.
- Cantidad de registros escritos.
- Historial de ejecuciones.

---

# 18. Inicialización de infraestructura

Las tablas internas de Spring Batch se inicializan mediante un script SQL incluido en el proyecto:

```text
src/main/resources/db/schema-spring-batch-postgresql.sql
```

Configuración:

```properties
spring.sql.init.mode=always
spring.sql.init.schema-locations=classpath:db/schema-spring-batch-postgresql.sql
```

La configuración permite mantener el esquema necesario para la persistencia del `JobRepository`.

Las entidades del dominio se administran en el entorno académico mediante Hibernate:

```properties
spring.jpa.hibernate.ddl-auto=update
```

---

# 19. Persistencia

PostgreSQL fue seleccionado como base de datos relacional.

La instancia de desarrollo se ejecuta utilizando Docker Compose.

Ventajas dentro del proyecto:

- Reproducibilidad.
- Separación del entorno local.
- Persistencia mediante volumen.
- Facilidad para reconstruir el ambiente.
- Compatibilidad con Spring Data JPA.
- Compatibilidad con el `JobRepository` JDBC de Spring Batch.

---

# 20. Riesgos identificados y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Datos CSV inválidos | Validación mediante `ItemProcessor` |
| Registro individual incorrecto | Skip controlado y auditoría |
| Fallo técnico transitorio | Política de retry |
| Duplicación entre ejecuciones | Reconciliación e idempotencia |
| Duplicados funcionales | Detección y clasificación `DUPLICADO` |
| Acceso concurrente inseguro al Reader | `SynchronizedItemStreamReader` |
| Configuración rígida | Parámetros externalizados |
| Pérdida de trazabilidad | Metadata JDBC de Spring Batch |
| Eliminación de historial | Uso de estado `activo` |
| Selección arbitraria de parámetros | Benchmark de threads y chunks |

---

# 21. Resultado técnico

La solución obtenida permite:

- Ejecutar los tres procesos solicitados.
- Validar y transformar la información de entrada.
- Persistir resultados en PostgreSQL.
- Mantener historial de Jobs y Steps.
- Detectar anomalías.
- Detectar duplicados.
- Mantener idempotencia.
- Registrar elementos rechazados.
- Procesar utilizando múltiples hilos.
- Modificar el tamaño de los chunks.
- Comparar parámetros de rendimiento.
- Aplicar reintentos ante fallos transitorios.
- Mantener la continuidad de la ejecución ante errores recuperables.

---

# 22. Configuración final seleccionada

Después de las pruebas realizadas se seleccionó como configuración base:

```text
Threads:          4
Queue Capacity:  20
Chunk Size:      10
Retry Max:        3
Retry Delay:    500 ms
Retry Demo:       0
```

La propiedad de demostración de retry se mantiene en:

```text
0
```

para garantizar que no se simulen fallos durante la operación normal.

---

# 23. Conclusión

La propuesta moderniza los procesos legacy del Banco XYZ mediante una arquitectura basada en Spring Batch, manteniendo separación de responsabilidades entre lectura, procesamiento, persistencia y control de errores.

El uso de procesamiento multihilo permite aplicar escalamiento horizontal dentro del Step, mientras que la parametrización de hilos y chunks permite ajustar el comportamiento sin modificar el código.

Las pruebas comparativas realizadas permiten seleccionar una configuración basada en evidencia para el dataset utilizado, en lugar de establecer valores arbitrarios.

Finalmente, la incorporación de políticas de skip, registro de rechazos y retry permite aumentar la resiliencia del procesamiento frente a registros inválidos y fallos técnicos recuperables.

La solución conserva además trazabilidad mediante PostgreSQL y el `JobRepository` de Spring Batch, permitiendo consultar tanto los resultados del negocio como el historial de las ejecuciones realizadas.

---

## Autora

**Natalia Alvarado**

Desarrollo Backend III — Semana 3.
