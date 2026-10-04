-- BancoXYZ Semana 5 - esquema reproducible para PostgreSQL 17
-- Se ejecuta automáticamente al crear el volumen por primera vez.

CREATE TABLE IF NOT EXISTS cuentas_intereses (
    cuenta_id BIGINT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    saldo_inicial NUMERIC(19,2) NOT NULL,
    tipo VARCHAR(30) NOT NULL,
    tasa_interes NUMERIC(10,4) NOT NULL,
    interes_calculado NUMERIC(19,2) NOT NULL,
    saldo_final NUMERIC(19,2) NOT NULL,
    estado VARCHAR(30) NOT NULL,
    observacion VARCHAR(255),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    ultima_instancia_id BIGINT
);

CREATE TABLE IF NOT EXISTS estados_cuenta_anuales (
    id BIGSERIAL PRIMARY KEY,
    cuenta_id BIGINT NOT NULL,
    anio INTEGER NOT NULL,
    total_depositos NUMERIC(19,2) NOT NULL,
    total_retiros NUMERIC(19,2) NOT NULL,
    total_compras NUMERIC(19,2) NOT NULL,
    saldo_anual NUMERIC(19,2) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    ultima_instancia_id BIGINT,
    CONSTRAINT uk_estado_cuenta_anio UNIQUE (cuenta_id, anio)
);

CREATE TABLE IF NOT EXISTS transacciones_procesadas (
    id BIGINT PRIMARY KEY,
    fecha DATE NOT NULL,
    monto NUMERIC(19,2) NOT NULL,
    tipo VARCHAR(30) NOT NULL,
    estado VARCHAR(30) NOT NULL,
    observacion VARCHAR(255),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    ultima_instancia_id BIGINT
);

CREATE TABLE IF NOT EXISTS resumen_transacciones_diarias (
    fecha DATE PRIMARY KEY,
    cantidad_transacciones BIGINT NOT NULL,
    total_creditos NUMERIC(19,2) NOT NULL,
    total_debitos NUMERIC(19,2) NOT NULL,
    saldo_neto NUMERIC(19,2) NOT NULL,
    ultima_instancia_id BIGINT
);

CREATE INDEX IF NOT EXISTS idx_estados_cuenta_cuenta_id ON estados_cuenta_anuales(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_transacciones_fecha ON transacciones_procesadas(fecha);
