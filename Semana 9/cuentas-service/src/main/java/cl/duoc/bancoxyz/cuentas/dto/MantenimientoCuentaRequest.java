package cl.duoc.bancoxyz.cuentas.dto;
import jakarta.validation.constraints.*;
public record MantenimientoCuentaRequest(@NotBlank @Size(max=100) String titular) {}
