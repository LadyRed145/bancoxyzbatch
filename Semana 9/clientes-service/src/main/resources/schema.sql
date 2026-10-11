-- Ejecutar SOLAMENTE tras validar instancia y hacer respaldo de laboratorio.
CREATE TABLE IF NOT EXISTS clientes_perfil (
 id BIGSERIAL PRIMARY KEY,
 nombre VARCHAR(120) NOT NULL,
 correo VARCHAR(254) NOT NULL UNIQUE,
 activo BOOLEAN NOT NULL DEFAULT TRUE
);
