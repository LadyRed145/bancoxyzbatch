# 🧪 BancoXYZ — Instrucciones de ejecución y pruebas · Semana 9

> **Evaluación Final Transversal · Desarrollo Backend III (PBY2203)**
> **Autora: Natalia Alvarado**

---

## 1. Alcance

Este documento indica cómo ejecutar y probar **cada componente** del sistema con el proyecto en su versión de Semana 9. Los comandos están preparados para **Fish** y se ejecutan desde la raíz `bancoxyzbatch/`. Los `.sh` se invocan con Bash.

### Reglas de integridad

- No editar los CSV de `Semana 9/batch-service/src/main/resources/data/`.
- No ejecutar `02_seed_processed_snapshot.sql`: es un artefacto histórico, no la carga actual.
- No eliminar tablas, volúmenes ni bases existentes para reiniciar una prueba.
- Las verificaciones de pagos crean **cuentas QA y movimientos persistentes**; no son de solo lectura.

---

## 2. Preparación

```fish
cp .env.example .env
chmod 600 .env
# Completa tus valores reales en .env sin subirlo a Git.
docker compose config --quiet
```

Compila y prueba todos los módulos:

```fish
./mvnw clean verify
```

Si solo se quiere preparar el contenedor o inspeccionar los servicios:

```fish
docker compose up -d --build
docker compose ps
```

---

## 3. Arquitectura y salud

| Componente | Qué comprobar | Comando recomendado |
|---|---|---|
| PostgreSQL | `healthy`, base `bancoxyz`, tablas presentes | `docker compose ps postgres` |
| Kafka 1/2/3 | tres brokers y topic replicado | `fish "Semana 9/scripts/verificar_kafka_cluster.fish"` |
| Kafka UI | visualización de brokers/lag | abrir `http://127.0.0.1:8090` |
| Keycloak | realm `bancoxyz`, tokens JWT | `fish "Semana 9/scripts/verificar_oauth2.fish"` |
| Config Server | propiedades por canal | `docker compose logs --tail=80 config-server` |
| Eureka | registros dinámicos del stack | `docker compose logs --tail=80 discovery-server` |
| Bank Backend | `healthy`, saldos y retiros | `docker compose ps bank-backend` |
| Retiros Consumer | recepción de eventos Kafka | `docker compose logs --tail=100 retiros-event-consumer` |
| BFF Web/Mobile/ATM | HTTPS y 401/403/200 | `fish "Semana 9/scripts/verificar_bff.fish"` |
| Cuentas Service | API gestión y estado | `docker compose ps cuentas-service` |
| Clientes Service | API perfiles y estado | `docker compose ps clientes-service` |
| Pagos Service | JWT, liquidación y persistencia | ver §5 |
| Keycloak EC2 S9 | realm, scopes, tres tokens Bearer emitidos por túnel SSH | ver §8 y `despliegue.md` |
| Escalado EC2 S9 | Cuentas, Clientes y Pagos 2/2/2 `healthy`, seis registros Eureka `UP` | ver §8 |
| Caddy EC2 | certificado Keycloak público (no configurado) | ver `despliegue.md` |

Las comprobaciones de rutas protegidas requieren JWT. No se deben imprimir tokens o client secrets en documentación pública.

---

## 4. Spring Batch: los tres archivos oficiales

```text
movimientos_financieros_diarios.csv → transaccionJob
intereses_trimestrales.csv          → cuentaInteresJob
estados_financieros_anuales.csv     → estadoCuentaAnualJob
```

Ejecutar:

```fish
bash "Semana 9/scripts/reparar_conexion_y_validar_batch_s9.sh"
```

Aceptar únicamente los tres Jobs `COMPLETED` tanto en la salida Spring como en las tablas de metadatos PostgreSQL. La última evidencia de Semana 9 registró ejecuciones `34/35/36` y tablas de 50, 474, 20 y 261 registros, respectivamente.

Para comprobar reejecución sin duplicación y huellas CSV, la suite integrada utilizada fue:

```fish
bash "Semana 9/scripts/cierre_final_qa_pagos_csv_s9.sh"
```

**Importante:** reejecuta Jobs y escribe metadatos de ejecución; no es una simple consulta informativa.

---

## 5. Operaciones monetarias: pagos, transferencias y depósitos

Endpoint principal: `POST /api/pagos/solicitudes` con JWT válido y `Idempotency-Key: UUID`. El cuerpo contiene `tipo`, `origen`, `destino`, `monto`.

| Caso | Resultado esperado |
|---|---|
| Transferencia o pago autorizado | `200`, `APLICADO`, débito/crédito correcto |
| Depósito autorizado | `200`, `APLICADO`, abono en destino |
| Reutilización de UUID con mismo cuerpo | Mismo recibo; ningún movimiento extra |
| Reutilización de UUID con otro cuerpo | HTTP `409` |
| Dos peticiones simultáneas con misma UUID | Una única liquidación |
| Token inválido | HTTP `401` |
| Reinicio de `pagos-service` | Los saldos y movimientos permanecen |

Para ejecutar pruebas QA con cuentas aisladas:

```fish
bash "Semana 9/scripts/verificar_pagos_tls_kafka_s9.sh" --laboratorio
```

Las pruebas del **11-10-2026** terminaron sin fallos: cuatro solicitudes `APLICADO`, siete movimientos únicos y saldos idénticos después del reinicio. El servicio opera sobre `cuentas_gestion`, **no** sobre la tabla derivada `cuentas_intereses` de Batch.

---

## 6. OAuth2, canales y resiliencia

```fish
fish "Semana 9/scripts/verificar_oauth2.fish"
fish "Semana 9/scripts/verificar_bff.fish"
fish "Semana 9/scripts/verificar_actuator_resilience.fish"
```

Para pruebas de fallo y recuperación, revisa antes las condiciones del script: algunas detienen/alteran servicios de laboratorio. No ejecutar contra infraestructura que atienda usuarios reales.

```fish
fish "Semana 9/scripts/verificar_resilience4j_fallo_recuperacion.fish"
```

El resultado esperado es `CLOSED → OPEN → HALF_OPEN → CLOSED` cuando el backend se degrada y se recupera.

---

## 7. Kafka: productor, consumidor y listener

```fish
fish "Semana 9/scripts/verificar_kafka_cluster.fish"
fish "Semana 9/scripts/verificar_kafka_microservicios.fish"
```

El topic `bancoxyz.retiros` tiene tres particiones, RF3 y min ISR2. La administración del listener usa las rutas `/api/kafka/consumer/estado`, `/resumen`, `/pausar` y `/reanudar` con JWT Web; **la prueba de pausa altera temporalmente el consumo**.

```fish
# Ejecutar solamente si se acepta interrumpir brevemente el listener:
fish "Semana 9/scripts/verificar_control_kafka_listener.fish"
```

Los brokers actuales utilizan `PLAINTEXT` y están en un único host Docker. No confundir con Kafka multi-AZ cifrado.

---

## 8. TLS público y despliegue Cloud

Los BFF tienen TLS 1.3 local mediante PKCS12 de laboratorio. En EC2 S9, PostgreSQL y Keycloak quedaron aislados bajo `bancoxyz-s9`, con acceso administrativo por túnel SSH y emisión JWT **3/3**. Después se verificaron Config Server, Eureka y las seis réplicas de los servicios de dominio.

**Evidencia AWS EC2 (11-10-2026):** en el proyecto independiente `bancoxyz-s9` se verificó el escalado horizontal de `cuentas-service`, `clientes-service` y `pagos-service` desde **1/1/1** hasta **2/2/2 réplicas**. Las **seis instancias** quedaron `healthy`; Eureka registró **dos instancias `UP` con identificadores distintos por servicio**. Config Server y Discovery Server también quedaron `healthy`. El host reportó **7,6 GiB de RAM total, 3,3 GiB utilizada y 4,3 GiB disponible**, sin swap. Se trata de seis réplicas sobre **una EC2**, no de alta disponibilidad multi-AZ; esta prueba no acredita por sí sola reparto efectivo de tráfico entre réplicas.

```bash
# En Ubuntu EC2, desde el checkout independiente de Semana 9:
cd "$HOME/bancoxyzbatch-s9"
bash "Semana 9/scripts/probar_escalado_horizontal_ec2_s9.sh"
# Para volver a la cantidad de réplicas previa sin borrar volúmenes:
bash "Semana 9/scripts/probar_escalado_horizontal_ec2_s9.sh" --restaurar
```

```bash
# En la consola SSH Ubuntu (Bash), dentro del checkout independiente S9:
cd "$HOME/bancoxyzbatch-s9"
docker compose -f docker-compose.s9.ec2.yml ps postgres keycloak
curl -fsS http://127.0.0.1:18084/realms/bancoxyz/.well-known/openid-configuration
```

```fish
# En el PC local con Fish (otra terminal, mantener el túnel abierto):
ssh -N -L 18084:127.0.0.1:18084 -i /ruta/privada/clave.pem ubuntu@IP_PUBLICA
# Abrir después http://localhost:18084/admin/ en el navegador.
```

Los cinco secretos nuevos están en el `.env` privado de EC2 S9 con permisos `600` (no regenerarlos ni mostrarlos). En Ubuntu se validaron los tres clientes con flujo `client_credentials` sin imprimir los tokens. La emisión JWT se comprobó en EC2; la prueba de escalado no constituye una validación extremo a extremo de BFF, Batch, Kafka o transacciones de Pagos en ese host.

Para TLS público se requiere DNS real, puertos 80/443 y certificado verificable. El script `Semana 9/scripts/desplegar_ec2_final.sh` corresponde a ese escenario futuro y **no se utilizó** en esta prueba privada. Consultar [`despliegue.md`](despliegue.md).

---

## 9. Auditoría y limpieza para entrega

Auditoría de código, Compose, pruebas y Batch:

```fish
bash "Semana 9/scripts/cierre_total_bancoxyz_s9.sh" --todo
```

Para liberar peso **únicamente** de directorios Maven `target/`:

```fish
bash "Semana 9/scripts/limpiar_targets_bancoxyz.sh" --dry-run
bash "Semana 9/scripts/limpiar_targets_bancoxyz.sh"
```

No utilizar como auditoría final el viejo `verificar_entrega_completa.fish`, que conserva conteos de etapas anteriores y un bloque Batch inhabilitado.

---

## 10. Referencia de evidencias técnicas

| Evidencia | Resultado observado |
|---|---|
| Spring Batch | Tres Jobs `COMPLETED`; reejecución sin cambios de huellas de negocio ni CSV |
| Keycloak en EC2 | Tres clientes OAuth2 con JWT Bearer emitidos (3/3) |
| Escalado horizontal en EC2 | Seis réplicas `healthy` y seis registros Eureka `UP`, con identificadores distintos |
| Infraestructura | Una EC2, proyectos Compose independientes, sin prueba multi-AZ |

---

**BancoXYZ · Natalia Alvarado · Desarrollo Backend III (PBY2203) · Semana 9**
