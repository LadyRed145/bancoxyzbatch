# Propuesta Técnica  
## Migración de Procesos Batch Legacy – Banco XYZ

### 1. Introducción

El presente documento describe la propuesta técnica para modernizar los procesos batch legacy del Banco XYZ mediante una solución desarrollada con **Spring Boot**, **Spring Batch** y **PostgreSQL**.

La actividad considera la reimplementación de tres procesos principales:

- Reporte de transacciones diarias.
- Cálculo de intereses mensuales.
- Generación de estados de cuenta anuales.

La solución tiene como objetivo mejorar la integridad y consistencia de los datos, incorporar manejo de errores, trazabilidad de ejecuciones y persistencia en una base de datos relacional.

---

## 2. Objetivo de la propuesta

Diseñar e implementar una arquitectura batch capaz de leer información proveniente de archivos CSV, aplicar reglas de validación y transformación mediante Spring Batch y persistir los resultados procesados en PostgreSQL.

La solución debe permitir:

- Procesar archivos CSV de forma estructurada.
- Detectar y corregir datos inconsistentes.
- Identificar anomalías.
- Registrar errores técnicos y de negocio.
- Evitar duplicaciones funcionales entre ejecuciones.
- Mantener trazabilidad de los Jobs y Steps ejecutados.
- Persistir resultados procesados en una base de datos relacional.

---

## 3. Arquitectura propuesta

La arquitectura se basa en el modelo tradicional de Spring Batch:

```text
Archivo CSV
    ↓
ItemReader
    ↓
ItemProcessor
    ↓
ItemWriter
    ↓
PostgreSQL
```

Cada proceso es implementado como un `Job` independiente compuesto por uno o más `Step`.

La solución utiliza los siguientes componentes principales:

- `ItemReader`: lectura de archivos CSV.
- `ItemProcessor`: validación, normalización y aplicación de reglas de negocio.
- `ItemWriter`: persistencia de datos procesados.
- `JobRepository`: almacenamiento de metadata de ejecución de Spring Batch.
- `Tasklet`: ejecución de procesos complementarios como reconciliación y generación de reportes.
- `SkipListener`: auditoría de registros descartados durante lectura, procesamiento o escritura.

---

## 4. Tecnologías seleccionadas

La solución utiliza las siguientes tecnologías:

- Java 21.
- Spring Boot 4.1.0.
- Spring Batch 6.
- Spring Data JPA.
- Hibernate.
- PostgreSQL 17.
- Maven.
- Docker y Docker Compose.
- Lombok.
- Git y GitHub.

PostgreSQL fue seleccionado como motor de base de datos relacional debido a su estabilidad, compatibilidad con Spring y facilidad de ejecución mediante contenedores Docker.

---

## 5. Procesos Batch implementados

### 5.1. Reporte de Transacciones Diarias

El proceso `transaccionJob` tiene como objetivo procesar las transacciones diarias del Banco XYZ.

El archivo de entrada posee el formato:

```text
id,fecha,monto,tipo
```

El procesamiento incluye validaciones sobre:

- Identificador.
- Fecha.
- Monto.
- Tipo de transacción.
- Montos iguales a cero.
- Tipos distintos de `debito` y `credito`.

Además, se incorpora una regla de normalización para débitos negativos.

Cuando se detecta un débito negativo, el monto es transformado a su valor absoluto y el registro queda marcado como:

```text
CORREGIDO
```

También se implementa detección de posibles duplicados considerando la combinación:

```text
fecha + monto + tipo
```

Si dos registros presentan los mismos valores pero poseen identificadores diferentes, el primer registro se conserva y los posteriores quedan marcados como:

```text
DUPLICADO
```

Los duplicados detectados no son incorporados nuevamente en el resumen financiero.

---

### 5.2. Resumen Diario de Transacciones

Como parte del `transaccionJob`, se implementa el Step:

```text
resumenTransaccionDiariaStep
```

Este proceso genera un resumen por fecha con:

- Cantidad de transacciones válidas.
- Total de créditos.
- Total de débitos.
- Saldo neto diario.

El saldo neto se calcula mediante:

```text
saldo_neto = total_creditos - total_debitos
```

Los registros rechazados y duplicados son excluidos de los totales financieros para evitar distorsiones en el reporte.

---

### 5.3. Cálculo de Intereses Mensuales

El proceso `cuentaInteresJob` procesa cuentas provenientes del archivo:

```text
cuenta_id,nombre,saldo,edad,tipo
```

Para efectos del caso académico se definieron las siguientes tasas:

```text
Cuenta de ahorro = 1%
Préstamo         = 2%
```

La fórmula utilizada es:

```text
interes = saldo × tasa
saldo_final = saldo + interes
```

Los resultados se redondean a dos decimales mediante `HALF_UP`.

Los estados posibles son:

```text
PROCESADO
SIN_INTERES
RECHAZADO
```

Una cuenta con saldo igual a cero queda como `SIN_INTERES`.

Un tipo de cuenta no soportado, como `hipoteca`, queda como `RECHAZADO` junto con una observación que indica la causa.

---

### 5.4. Generación de Estados de Cuenta Anuales

El proceso `estadoCuentaAnualJob` consolida los movimientos anuales de cada cuenta.

El archivo de entrada posee el formato:

```text
cuenta_id,fecha,transaccion,monto,descripcion
```

Los tipos de movimiento considerados son:

```text
deposito
retiro
compra
```

Las reglas aplicadas son:

- Los depósitos se normalizan como valores positivos.
- Los retiros se normalizan como valores negativos.
- Las compras se normalizan como valores negativos.
- Los movimientos con monto igual a cero son considerados inválidos.

El resultado consolidado contiene:

- Cuenta.
- Año.
- Total de depósitos.
- Total de retiros.
- Total de compras.
- Saldo anual.

La persistencia incluye una restricción única sobre:

```text
cuenta_id + anio
```

con el objetivo de evitar duplicados funcionales en los estados anuales.

---

## 6. Manejo de errores

La propuesta incorpora tolerancia a fallos mediante Spring Batch.

Los Steps principales permiten manejar errores en las fases:

```text
READ
PROCESS
WRITE
```

Los registros descartados son almacenados en la tabla:

```text
registros_rechazados
```

Esta tabla permite registrar:

- Nombre del Job.
- Nombre del Step.
- Fase en que ocurrió el error.
- Número de línea.
- Contenido original.
- Tipo de error.
- Mensaje de error.
- Identificador de JobInstance.
- Fecha del registro.

Este mecanismo permite distinguir entre errores técnicos y errores de negocio.

Ejemplos:

- Error técnico de lectura por formato CSV inválido.
- Error de negocio por movimiento anual con monto igual a cero.

La configuración fault-tolerant permite que un registro inválido pueda ser omitido sin provocar necesariamente el fallo completo del Job.

---

## 7. Persistencia de datos

Los datos procesados se almacenan en PostgreSQL.

Las principales tablas de negocio son:

```text
transacciones_procesadas
resumen_transacciones_diarias
cuentas_intereses
estados_cuenta_anuales
registros_rechazados
```

Además, Spring Batch utiliza sus propias tablas de metadata para mantener trazabilidad de las ejecuciones:

```text
BATCH_JOB_INSTANCE
BATCH_JOB_EXECUTION
BATCH_JOB_EXECUTION_PARAMS
BATCH_JOB_EXECUTION_CONTEXT
BATCH_STEP_EXECUTION
BATCH_STEP_EXECUTION_CONTEXT
```

El esquema oficial de Spring Batch para PostgreSQL se encuentra versionado dentro del proyecto.

---

## 8. Reconciliación e idempotencia

La solución incorpora un mecanismo de reconciliación para evitar pérdida de información histórica y duplicación funcional.

Cada registro procesado mantiene los campos:

```text
activo
ultima_instancia_id
```

Durante una ejecución:

- Los registros presentes en el archivo son marcados como activos.
- Se actualiza `ultima_instancia_id` con la JobInstance actual.
- Los registros históricos que ya no aparecen en el archivo son conservados y marcados como inactivos.
- Si un registro reaparece posteriormente, vuelve a quedar activo.

Este enfoque permite mantener historial de información sin eliminar físicamente registros.

También evita duplicaciones durante nuevas ejecuciones de los procesos.

---

## 9. Infraestructura de ejecución

PostgreSQL se ejecuta mediante Docker Compose.

La configuración local utiliza:

```text
Base de datos: bancoxyz
Usuario: bancoxyz
Puerto: 5432
```

La aplicación permite configurar la conexión mediante variables de entorno:

```text
DB_URL
DB_USER
DB_PASSWORD
```

Esto permite mantener flexibilidad entre el entorno académico y futuras configuraciones externas.

---

## 10. Control de ejecución de Jobs

La ejecución automática de Jobs se encuentra deshabilitada mediante:

```properties
spring.batch.job.enabled=false
```

La aplicación utiliza `ControlledJobRunner` para seleccionar explícitamente qué Job debe ejecutarse.

Los parámetros requeridos son:

```text
app.batch.job
app.batch.run-id
```

Ejemplo:

```bash
./mvnw spring-boot:run \
  -Dspring-boot.run.arguments="--app.batch.job=transaccionJob --app.batch.run-id=1"
```

Cada valor nuevo de `run-id` representa una nueva JobInstance.

---

## 11. Versionamiento

El proyecto se encuentra versionado mediante Git y publicado en un repositorio GitHub bajo una cuenta propia.

El repositorio contiene:

- Código fuente.
- Configuración Maven.
- Maven Wrapper.
- Docker Compose.
- Archivos CSV de entrada.
- Esquema PostgreSQL para Spring Batch.
- Configuración de aplicación.
- Pruebas.
- Documentación técnica.

El archivo `.gitignore` excluye artefactos generados y archivos locales que no forman parte del código fuente, como:

- `target/`.
- Logs.
- Variables locales.
- Backups.
- Dumps.
- Configuraciones de IDE.

---

## 12. Pruebas y validaciones realizadas

Durante el desarrollo se realizaron pruebas sobre:

- Compilación del proyecto.
- Carga del contexto Spring Boot.
- Ejecución de `transaccionJob`.
- Ejecución de `cuentaInteresJob`.
- Ejecución de `estadoCuentaAnualJob`.
- Persistencia de datos.
- Detección de duplicados.
- Normalización de débitos negativos.
- Rechazo de transacciones con monto cero.
- Cálculo de intereses.
- Rechazo de tipos de cuenta no soportados.
- Consolidación anual.
- Manejo de errores de lectura.
- Manejo de errores de negocio.
- Registro de errores en base de datos.
- Reejecución sin duplicación funcional.
- Desactivación de registros ausentes.
- Reactivación de registros históricos.

Las ejecuciones finales de los tres Jobs finalizaron correctamente con estado:

```text
COMPLETED
```

---

## 13. Decisiones de diseño

La solución adopta las siguientes decisiones técnicas:

### Persistencia histórica

No se eliminan automáticamente registros que desaparecen de un archivo de entrada.

Se utiliza un campo `activo` para conservar el historial y permitir futuras reactivaciones.

### Errores auditables

Los errores descartados no se limitan a mensajes de consola.

Se almacenan en una tabla específica para facilitar trazabilidad y auditoría.

### Separación por responsabilidad

La solución mantiene componentes separados para:

- Lectura.
- Procesamiento.
- Escritura.
- Configuración de Jobs.
- Repositorios.
- Modelos.
- Manejo de errores.
- Reconciliación.

Esto mejora la mantenibilidad del proyecto.

### Reportes derivados

El resumen de transacciones diarias se genera a partir del estado procesado de las transacciones.

Los registros rechazados y duplicados no afectan los totales financieros.

---

## 14. Consideraciones para producción

La implementación actual corresponde a un entorno académico y de desarrollo.

Para un ambiente productivo se recomienda:

- Utilizar un gestor de secretos.
- Eliminar credenciales predeterminadas.
- Utilizar Flyway o Liquibase para migraciones de base de datos.
- Deshabilitar `spring.jpa.hibernate.ddl-auto=update`.
- Implementar monitoreo y métricas.
- Incorporar políticas de reintento.
- Ampliar las pruebas automatizadas.
- Utilizar una instancia administrada de PostgreSQL.
- Incorporar políticas de respaldo.
- Aplicar principio de mínimo privilegio.
- Incorporar pipelines CI/CD.

---

## 15. Conclusión

La propuesta implementa una modernización de los procesos batch legacy del Banco XYZ utilizando Spring Batch.

La solución permite procesar los tres flujos solicitados:

- Transacciones diarias.
- Intereses mensuales.
- Estados de cuenta anuales.

Además, incorpora validación, transformación, detección de anomalías, persistencia, manejo de errores, auditoría, reconciliación e idempotencia.

La arquitectura propuesta permite mantener separación de responsabilidades y facilita futuras extensiones del sistema, manteniendo trazabilidad de los procesos ejecutados y consistencia en la información almacenada.
