package cl.duoc.bancoxyz.bffatm.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record AtmRetiroRequest(
        // Valido el formato mínimo en el borde y mantengo la misma regla en el backend como defensa adicional.
        @NotNull
        @DecimalMin(value = "1.00")
        BigDecimal monto
) {
}
