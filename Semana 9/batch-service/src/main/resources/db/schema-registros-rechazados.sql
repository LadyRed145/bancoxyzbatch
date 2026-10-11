-- Extensión ADITIVA del esquema de negocio para el módulo Batch.
-- Solo para la instancia PostgreSQL de pruebas, no ejecutar en producción sin revisión.
CREATE TABLE IF NOT EXISTS registros_rechazados (
    id BIGSERIAL PRIMARY KEY,
    job_name VARCHAR(100) NOT NULL,
    step_name VARCHAR(100) NOT NULL,
    fase VARCHAR(30) NOT NULL,
    numero_linea BIGINT,
    contenido_original VARCHAR(2000),
    tipo_error VARCHAR(255) NOT NULL,
    mensaje_error VARCHAR(2000),
    job_instance_id BIGINT,
    fecha_registro TIMESTAMP NOT NULL
);
