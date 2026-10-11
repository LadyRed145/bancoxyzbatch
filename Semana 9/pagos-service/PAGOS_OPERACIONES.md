# BancoXYZ S9 · Procesamiento de pagos, transferencias y depósitos

## Alcance y fuente de saldos

`pagos-service` implementa liquidación **real dentro del entorno de laboratorio**, en una transacción PostgreSQL, sobre las cuentas administrativas creadas mediante `POST /api/cuentas/gestion` (`cuentas_gestion`).

**No toca `cuentas_intereses`, los CSV legacy ni el resultado de Spring Batch.** La tabla `cuentas_intereses` se regenera con los Jobs Batch y no debe emplearse como libro mayor del servicio de pagos.

La primera operación sobre una cuenta inicializa `pagos_saldos.saldo_actual` con `cuentas_gestion.saldo_inicial`. Posteriormente solo se modifica mediante transacciones de `pagos-service`.

## API

JWT válido con uno de los scopes `bancoxyz.web`, `bancoxyz.mobile` o `bancoxyz.atm`:

- `POST /api/pagos/solicitudes` con cabecera `Idempotency-Key: <UUID>` y cuerpo `{"tipo":"TRANSFERENCIA","origen":1,"destino":2,"monto":10.00}`.
- `GET /api/pagos/solicitudes/{uuid}` devuelve el estado (`APLICADO` para operaciones exitosas).
- `GET /api/pagos/cuentas/{id}/saldo` consulta el saldo actual calculado por este servicio.

`TRANSFERENCIA` y `PAGO` debitan el origen y acreditan el destino (ambas cuentas deben estar `ACTIVA`). `DEPOSITO` acredita únicamente el destino; el `origen` es una referencia externa positiva y **no se debita ninguna cuenta interna**. En un banco real, el ingreso externo requeriría validación y autorización de la entidad proveedora; esta implementación es solo demostrativa.

El cambio de saldos, la inserción de movimientos y el estado `APLICADO` se confirman en una **sola transacción**. Ante error se revierten íntegramente.

## Integridad e idempotencia

- UUID de idempotencia única: repetir exactamente la operación devuelve el recibo sin mover dinero de nuevo.
- Reutilizar el UUID con otro importe o cuentas da `409`.
- UUID históricas `PENDIENTE` no se ejecutan por sorpresa: dan `409` y permanecen intactas.
- Bloqueos de filas en orden estable evitan transferencias concurrentes con saldos inconsistentes.
- Saldo insuficiente y cuenta cerrada dan `409`; cuenta inexistente, `404`.
- La migración SQL es aditiva y no usa `TRUNCATE`, `DELETE`, `DROP TABLE` ni modifica los CSV.

## Limitación explícita

Este flujo funciona con **cuentas_gestion**, no con retiros de la API legacy `/api/cuentas/{id}/retiro` (la cual opera sobre otra representación de cuentas). No hay integración con redes de pago externas, conciliación interbancaria, autorización por titular de cuenta, ni contabilidad de doble partida completa para depósitos externos. No usar para dinero real.

Para probar manualmente, crea previamente dos cuentas con la API de gestión (saldos de laboratorio), obtén un JWT con scope válido y usa **UUID distintas** por operación. Repite una UUID con el mismo cuerpo para verificar no duplicación. Comprueba saldos con el GET dedicado.
