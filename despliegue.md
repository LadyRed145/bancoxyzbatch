# ☁️ BancoXYZ — Guía de despliegue · Semana 9

> **Desarrollo Backend III (PBY2203) · Evaluación Final Transversal**
> **Autora: Natalia Alvarado**
> Docker Compose · PostgreSQL 17 · Keycloak · TLS · Kafka · Spring Cloud · AWS EC2

---

## 🧭 Antes de comenzar

Esta guía sigue un flujo único y reproducible: **preparar → configurar → validar → desplegar → comprobar → documentar**. Se ejecuta desde la raíz de `bancoxyzbatch` y los comandos están escritos para **Fish**. Los scripts que terminan en `.sh` se ejecutan con `bash`, no con `fish`.

**Qué se despliega:** 16 servicios locales de Docker Compose más Caddy bajo el perfil `ec2`. Spring Batch **no es un servicio permanente de Compose**: sus Jobs se ejecutan explícitamente y escriben en la base PostgreSQL `bancoxyz`.

**Regla de integridad:** no editar los tres CSV originales, no reimportar snapshots antiguos y no ejecutar `docker compose down -v`, `DROP`, `TRUNCATE` ni limpiar volúmenes para probar la instalación.

---

## 1. Requisitos previos

| Componente | Local | AWS EC2 |
|---|---|---|
| Java | 21 | Incluido en las imágenes de servicios; útil en host para pruebas |
| Maven | `./mvnw` incluido | Imagen Maven en Docker / wrapper opcional |
| Docker | Engine + Compose v2 | Engine + Compose v2 |
| Sistema | Linux/Fish (o shell equivalente) | Ubuntu Server Linux |
| PostgreSQL | Contenedor `postgres:17` | Mismo contenedor en laboratorio Cloud |
| Kafka | Tres brokers KRaft locales | Tres brokers en la EC2, o clúster externo configurado |
| DNS público | No necesario | **Opcional para prueba privada SSH**; requerido para HTTPS público confiable |
| Seguridad de red | Puertos de laboratorio restringidos | Security Group, TLS y puertos 80/443 |

Para la arquitectura completa se recomienda disponer de memoria suficiente: los tres brokers, Keycloak, Kafka UI y las aplicaciones JVM arrancan simultáneamente.

Comprobaciones iniciales:

```fish
docker --version
docker compose version
git --version
java -version
./mvnw -version
```

---

## 2. Obtener el código correcto

Repositorio: https://github.com/LadyRed145/bancoxyzbatch

```fish
git clone https://github.com/LadyRed145/bancoxyzbatch.git
cd bancoxyzbatch
```

**Publicación comprobada (11-10-2026):** la rama `main` publicada y el checkout de EC2 S9 se verificaron en el commit `cf4605f`, con los tests, el código de Semana 9 y `docker-compose.s9.ec2.yml`. Tras actualizar estos cuatro `.md`, publicar un nuevo commit y sincronizarlo en la carpeta S9 de EC2 con `git fetch` + `git merge --ff-only`, sin alterar Semana 8.

```fish
git status --short
git branch --show-current
ls "Semana 9/batch-service/src/main/resources/data/"
```

Si una EC2 ya tiene el repositorio clonado, no sobrescribir cambios locales con `git reset --hard` o `git clean -fd`. Para Semana 9 se usa exclusivamente `/home/ubuntu/bancoxyzbatch-s9`; la Semana 8 sigue en `/home/ubuntu/bancoxyzbatch`. El desplegador oficial de TLS público exige checkout limpio y usa `git pull --ff-only`, pero **no forma parte de la prueba privada ya realizada**.

---

## 3. Configurar entorno local sin exponer secretos

```fish
cp .env.example .env
chmod 600 .env
```

Editar `.env` en el equipo sin publicarlo. Completar **variables reales** de PostgreSQL, Keycloak, secretos de clientes OAuth2 y keystore. Los certificados PKCS12 incluidos son **académicos**, no válidos como identidad pública de producción.

Variables principales:

```text
POSTGRES_DB=bancoxyz
POSTGRES_USER=<usuario_local>
POSTGRES_PASSWORD=<secreto_local>
KEYCLOAK_PUBLIC_URL=<URL local coherente con el issuer>
OAUTH2_ISSUER_URI=<issuer de los tokens>
OAUTH2_WEB_CLIENT_SECRET=<secreto>
OAUTH2_MOBILE_CLIENT_SECRET=<secreto>
OAUTH2_ATM_CLIENT_SECRET=<secreto>
SSL_KEYSTORE_PASSWORD=<contraseña del certificado de laboratorio>
KAFKA_MODE=local
KAFKA_BOOTSTRAP_SERVERS=kafka-1:19092,kafka-2:19092,kafka-3:19092
KAFKA_SECURITY_PROTOCOL=PLAINTEXT
```

> Los valores entre `<>` son ilustrativos. La contraseña de la base y los secretos OAuth2 no se escriben dentro de los documentos ni se incluyen en el ZIP del AVA.

---

## 4. Validar configuración y levantar el stack local

```fish
docker compose config --quiet
and docker compose up -d --build
and docker compose ps
```

Orden de dependencias representado por Compose:

```text
PostgreSQL + Kafka
        ↓
Keycloak + Config Server + Eureka
        ↓
Bank Backend + Consumer + Cuentas + Clientes + Pagos
        ↓
BFF Web + Mobile + ATM
```

Compose utiliza healthchecks para controlar el arranque. Los tres BFF publican HTTPS de laboratorio en los puertos `8081`, `8082` y `8083`. Kafka UI se consulta en `127.0.0.1:8090`. Keycloak usa `127.0.0.1:8084` por defecto en el host.

**No confundir:** que los contenedores aparezcan `healthy` no significa que los tres Jobs Batch ya se hayan ejecutado.

---

## 5. PostgreSQL y migraciones controladas

La base única se denomina `bancoxyz`. Para un volumen PostgreSQL **nuevo**, Compose monta el esquema inicial y las migraciones de Spring Batch y microservicios en `/docker-entrypoint-initdb.d`.

```text
Semana 9/database/01_schema.sql
Semana 9/data/db/03_retiros_idempotencia.sql
Semana 9/data/db/04_pagos_operaciones.sql
Semana 9/batch-service/src/main/resources/db/...
Semana 9/cuentas-service/src/main/resources/db/migration/...
Semana 9/clientes-service/src/main/resources/schema.sql
Semana 9/pagos-service/src/main/resources/schema.sql
```

En un volumen **existente**, los scripts de `initdb.d` **no vuelven a ejecutarse**. Las migraciones adicionales se aplican explícitamente solo cuando corresponde; no se debe vaciar el volumen para forzar la inicialización.

Consulta segura de estado:

```fish
docker compose ps postgres

docker compose exec postgres psql -U bancoxyz -d bancoxyz -c '\dt'
```

Si tu `.env` define otro usuario/nombre de base, sustitúyelos en el comando. En Semana 9, `pagos-service` usa `spring.sql.init.mode=never` porque la migración con bloque `DO` se aplica mediante PostgreSQL y **no** por el parser SQL de Spring Boot al arrancar.

> El archivo histórico `Semana 9/database/02_seed_processed_snapshot.sql` **no forma parte del flujo de carga** actual. No montarlo, ejecutarlo ni tratarlo como fuente de datos de Semana 9.

---

## 6. Ejecutar los tres Jobs Spring Batch

Las fuentes únicas de esta etapa están en:

```text
Semana 9/batch-service/src/main/resources/data/
├── movimientos_financieros_diarios.csv
├── intereses_trimestrales.csv
└── estados_financieros_anuales.csv
```

Ejecutar la verificación controlada, que detecta PostgreSQL y exige `COMPLETED` persistido por cada Job:

```fish
bash "Semana 9/scripts/reparar_conexion_y_validar_batch_s9.sh"
```

**Efectos:** escribe resultados derivados de los Jobs y metadatos Batch; no modifica los CSV. La idempotencia ya se comprobó con huellas de las cuatro tablas de negocio, pero ninguna prueba debe lanzarse indiscriminadamente sobre una base productiva real.

Resultados de referencia de la validación del **11 de octubre de 2026**:

```text
transaccionJob        → COMPLETED
cuentaInteresJob      → COMPLETED
estadoCuentaAnualJob  → COMPLETED

cuentas_intereses ............... 50
transacciones_procesadas ....... 474
estados_cuenta_anuales ......... 20
resumen_transacciones_diarias .. 261
```

---

## 7. Verificar autenticación, servicios y persistencia

Pruebas que no crean cuentas nuevas:

```fish
fish "Semana 9/scripts/verificar_oauth2.fish"
fish "Semana 9/scripts/verificar_bff.fish"
fish "Semana 9/scripts/verificar_kafka_cluster.fish"
```

Pruebas de laboratorio **que sí crean movimientos sobre cuentas QA**, no clientes reales:

```fish
bash "Semana 9/scripts/verificar_pagos_tls_kafka_s9.sh" --laboratorio
```

Este último valida JWT, pagos/transferencias/depósitos, UUID repetidas y concurrentes, persistencia PostgreSQL y reinicio **solo** de `pagos-service`. También inspecciona TLS de los tres BFF y Kafka local. Puede emitir avisos válidos porque no existe dominio público o clúster multi-AZ.

Para el cierre conjunto previamente ensayado (Pagos + reejecución de Batch + huellas CSV):

```fish
bash "Semana 9/scripts/cierre_final_qa_pagos_csv_s9.sh"
```

**Advertencia:** ese cierre produce metadatos Batch y operaciones QA, así que se usa solo cuando haya intención explícita de repetir el laboratorio. No hace falta relanzarlo para documentar una ejecución que ya terminó con código `0`.

---

## 8. Despliegue en AWS EC2 con TLS público de Keycloak

**Estado real verificado el 11-10-2026:** en `/home/ubuntu/bancoxyzbatch-s9` se comprobó el proyecto independiente `bancoxyz-s9`, con PostgreSQL 17, Keycloak 26.8.0 y emisión JWT **3/3**. Después se iniciaron Config Server, Eureka y los servicios Cuentas, Clientes y Pagos para verificar el escalado horizontal **2/2/2**. Las seis réplicas quedaron `healthy` y Eureka reconoció dos instancias `UP` por servicio. Se midieron 7,6 GiB de RAM total, 3,3 GiB usada y 4,3 GiB disponible, sin swap. No se configuró HTTPS público ni se acreditó alta disponibilidad multi-AZ.

**Evidencia AWS EC2 (11-10-2026):** en el proyecto independiente `bancoxyz-s9` se verificó el escalado horizontal de `cuentas-service`, `clientes-service` y `pagos-service` desde **1/1/1** hasta **2/2/2 réplicas**. Las **seis instancias** quedaron `healthy`; Eureka registró **dos instancias `UP` con identificadores distintos por servicio**. Config Server y Discovery Server también quedaron `healthy`. El host reportó **7,6 GiB de RAM total, 3,3 GiB utilizada y 4,3 GiB disponible**, sin swap. Se trata de seis réplicas sobre **una EC2**, no de alta disponibilidad multi-AZ; esta prueba no acredita por sí sola reparto efectivo de tráfico entre réplicas.

```bash
# En Ubuntu EC2, desde el checkout independiente de Semana 9:
cd "$HOME/bancoxyzbatch-s9"
bash "Semana 9/scripts/probar_escalado_horizontal_ec2_s9.sh"
# Para volver a la cantidad de réplicas previa sin borrar volúmenes:
bash "Semana 9/scripts/probar_escalado_horizontal_ec2_s9.sh" --restaurar
```

```bash
# En la EC2, siempre dentro del directorio exclusivo de S9 (Bash):
cd "$HOME/bancoxyzbatch-s9"
docker compose -f docker-compose.s9.ec2.yml ps postgres keycloak config-server discovery-server cuentas-service clientes-service pagos-service
curl -fsS http://127.0.0.1:18084/realms/bancoxyz/.well-known/openid-configuration
```

```fish
# En el equipo local, NO dentro de Ubuntu (Fish):
ssh -N -L 18084:127.0.0.1:18084 -i /ruta/privada/clave.pem ubuntu@184.193.6.63
# Consola de administración: http://localhost:18084/admin/
```

**Seguridad del laboratorio:** los cinco secretos nuevos de S9 se guardaron en el `.env` privado con modo `600`, sin exponer su contenido. Se usó `KEYCLOAK_START_COMMAND=start-dev` para esta sesión privada. El banner indica administrador temporal; antes de un despliegue permanente, crear un administrador definitivo, revisar los secretos y habilitar TLS seguro. La emisión de JWT no certifica todavía que los BFF de S9 validen los tokens en EC2.

Los apartados 8.1 a 8.5 describen la **alternativa futura con DNS real y HTTPS**, no el despliegue que ya se comprobó.

### 8.1 Infraestructura y red

Para una publicación HTTPS futura, crear o adaptar una instancia EC2 Linux con CPU, RAM y disco suficientes, IP pública estable, Docker Engine, Compose y Git. Restringir el Security Group: abrir `22/TCP` **solo desde la IP administradora** y `80/TCP` + `443/TCP` a los clientes externos autorizados. En la prueba privada actual **no fue necesario abrir 80/443**; los puertos internos de PostgreSQL, Keycloak, Kafka, Eureka, Config Server y Kafka UI **no** deben publicarse en Internet.

Los BFF tienen puertos HTTPS de laboratorio `8081–8083`; si se exponen, limitar origen en el Security Group. **Caddy en este repositorio publica únicamente Keycloak**, no actúa como proxy público de los tres BFF.

### 8.2 DNS público real

Configurar un registro A, por ejemplo:

```text
auth.DOMINIO_REAL → IP_PÚBLICA_DE_EC2
```

Esperar resolución DNS y comprobar el puerto 80/443. Un nombre como `tu-dominio.cl` sin un registro válido **no es evidencia TLS**.

### 8.3 Preparar `.env` de Cloud

```fish
cp .env.ec2.example .env
chmod 600 .env
```

Completar secretos e issuer, de forma coherente:

```text
KEYCLOAK_DOMAIN=auth.DOMINIO_REAL
TLS_EMAIL=correo_de_administracion_real
KEYCLOAK_PUBLIC_URL=https://auth.DOMINIO_REAL
OAUTH2_ISSUER_URI=https://auth.DOMINIO_REAL/realms/bancoxyz
OAUTH2_TOKEN_URL=http://127.0.0.1:8084/realms/bancoxyz/protocol/openid-connect/token
KEYCLOAK_START_COMMAND=start
KAFKA_MODE=local
```

Ajustar `KC_DB_SCHEMA`/Keycloak y los secretos según las plantillas reales. No pegar credenciales en capturas, Git, vídeo ni informe.

### 8.4 Validar y desplegar

Desde el checkout **limpio** del mismo commit de la entrega:

```fish
docker compose --profile ec2 config --quiet
and bash "Semana 9/scripts/desplegar_ec2_final.sh"
```

El script de despliegue existente comprueba variables, DNS, Git, recursos, estado PostgreSQL/Kafka, compilación de imágenes, healthchecks y finalmente HTTPS público de Keycloak. Realiza `git pull --ff-only` antes de construir: **no usarlo con archivos locales sin subir**, porque el checkout debe reflejar el commit a presentar. **No se ejecutó este script** para la prueba privada; se utilizó `docker-compose.s9.ec2.yml` para PostgreSQL, Keycloak, Config Server, Eureka y el escalado de los servicios de dominio.

### 8.5 Certificado realmente válido

Sin desactivar validación TLS:

```fish
curl --fail --show-error --silent \
  https://auth.DOMINIO_REAL/realms/bancoxyz/.well-known/openid-configuration
```

Comprobar que la respuesta OIDC tenga el `issuer` esperado y que el navegador confíe en la cadena. **Solo después** registrar «TLS público válido» en la evidencia. Los BFF seguirán con certificados de laboratorio a menos que se configure su propia publicación HTTPS pública.

---

## 9. Escalabilidad horizontal de los microservicios

**Evidencia AWS EC2 (11-10-2026):** en el proyecto independiente `bancoxyz-s9` se verificó el escalado horizontal de `cuentas-service`, `clientes-service` y `pagos-service` desde **1/1/1** hasta **2/2/2 réplicas**. Las **seis instancias** quedaron `healthy`; Eureka registró **dos instancias `UP` con identificadores distintos por servicio**. Config Server y Discovery Server también quedaron `healthy`. El host reportó **7,6 GiB de RAM total, 3,3 GiB utilizada y 4,3 GiB disponible**, sin swap. Se trata de seis réplicas sobre **una EC2**, no de alta disponibilidad multi-AZ; esta prueba no acredita por sí sola reparto efectivo de tráfico entre réplicas.

```bash
# En Ubuntu EC2, desde el checkout independiente de Semana 9:
cd "$HOME/bancoxyzbatch-s9"
bash "Semana 9/scripts/probar_escalado_horizontal_ec2_s9.sh"
# Para volver a la cantidad de réplicas previa sin borrar volúmenes:
bash "Semana 9/scripts/probar_escalado_horizontal_ec2_s9.sh" --restaurar
```


Compose permite réplicas para los tres servicios solicitados por la pauta:

```fish
set -lx CUENTAS_REPLICAS 2
set -lx CLIENTES_REPLICAS 2
set -lx PAGOS_REPLICAS 2

docker compose up -d --build \
  --scale cuentas-service=2 \
  --scale clientes-service=2 \
  --scale pagos-service=2
```

En EC2, si se está utilizando Caddy:

```fish
docker compose --profile ec2 up -d \
  --scale cuentas-service=2 \
  --scale clientes-service=2 \
  --scale pagos-service=2
```

**Verificar:** dos instancias por servicio, registros Eureka, llamadas funcionales y ausencia de colisiones de puerto. La replicación en el mismo host **no es alta disponibilidad multi-AZ**; para ello se necesitan nodos en distintas zonas y balanceadores gestionados.

---

## 10. Kafka: laboratorio frente a nube administrada

### Configuración actual (verificada)

```text
KAFKA_MODE=local
KAFKA_BOOTSTRAP_SERVERS=kafka-1:19092,kafka-2:19092,kafka-3:19092
KAFKA_SECURITY_PROTOCOL=PLAINTEXT
Topic: bancoxyz.retiros · 3 particiones · RF=3 · min ISR=2
```

Esto demuestra replicación entre **tres brokers del mismo host**, no Kafka multi-AZ, TLS/SASL ni monitoreo centralizado.

### Para migrar a Kafka administrado / multi-AZ

Aprovisionar **realmente** brokers distribuidos (p. ej. Amazon MSK en subredes de varias zonas), redes privadas, autenticación y cifrado según el clúster elegido, monitoreo y alarmas. Actualizar las propiedades de productor (`bank-backend`) y consumidor (`retiros-event-consumer`) para el protocolo específico (`SSL` o `SASL_SSL` con mecanismo y credenciales compatibles). Las variables que acepta el proyecto deben confirmarse para ese proveedor: **no suponer que cambiar `KAFKA_MODE=external` crea MSK o configura SASL automáticamente**.

Migrar tópicos y consumidores con pruebas de entrega, offsets, lag y fallos antes de retirar el clúster antiguo.

---

## 11. Operación, diagnósticos y reversa sin pérdida de datos

```fish
# Comprobar servicios:
docker compose ps

# Ver únicamente registros recientes de pagos:
docker compose logs --tail=120 pagos-service

# Detener servicios sin eliminar volúmenes:
docker compose stop

# Volver a iniciar con la configuración existente:
docker compose start
```

Para inspeccionar el entorno privado comprobado de Semana 9, **en Ubuntu/Bash**:

```bash
cd "$HOME/bancoxyzbatch-s9"
docker compose -f docker-compose.s9.ec2.yml ps postgres keycloak config-server discovery-server cuentas-service clientes-service pagos-service
docker compose -f docker-compose.s9.ec2.yml logs --tail=120 keycloak
```

Si en el futuro se configura el perfil EC2 completo con DNS/Caddy, emplear sus comandos de operación separados, comprobando antes los puertos, recursos y la independencia con Semana 8.

No hacer `docker compose down -v`, no ejecutar SQL del snapshot histórico, ni sobrescribir CSV; las pruebas de laboratorio y la base actual se preservan.

---

## 12. Evidencias técnicas verificadas

| Área | Resultado |
|---|---|
| Spring Batch | Tres Jobs `COMPLETED`, cuatro tablas derivadas sin cambios en reejecución |
| Keycloak S9 en EC2 | Realm `bancoxyz`, scopes de canal y emisión JWT 3/3 |
| Config Server y Eureka | Ambos `healthy` en la EC2 |
| Cuentas, Clientes y Pagos | Escalado horizontal 2/2/2, seis contenedores `healthy` |
| Eureka | Dos instancias `UP` por servicio, IDs distintos |
| Límite de la prueba | Una EC2; sin validación multi-AZ ni distribución de tráfico |

---

## ✅ Conclusión

El despliegue de BancoXYZ comienza con código coherente, variables protegidas y servicios saludables; continúa con verificación explícita de las tres fuentes CSV, JWT, microservicios y mensajería; y termina con evidencias documentadas. La verificación local del 11-10-2026 fue exitosa en Batch/Pagos; en EC2 también se validaron **PostgreSQL y Keycloak de S9 de forma aislada**, con realm, scopes y tres tokens Bearer emitidos. **TLS público, resto del stack Cloud y escalabilidad efectiva siguen pendientes** y no se presentan como certificados.

---

**BancoXYZ · Natalia Alvarado · Desarrollo Backend III (PBY2203) · Semana 9**
