-- BancoXYZ Semana 9. Migración ADITIVA: segura al repetirla.
-- No elimina tablas, cuentas, CSV ni filas de negocio.
CREATE TABLE IF NOT EXISTS retiros_idempotencia (
  clave UUID PRIMARY KEY,
  cuenta_id BIGINT NOT NULL,
  monto NUMERIC(19,2) NOT NULL CHECK (monto > 0),
  saldo_final NUMERIC(19,2) NOT NULL,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_retiros_idemp_cuenta ON retiros_idempotencia(cuenta_id);
