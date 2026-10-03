package cl.duoc.bancoxyz.bffatm.dto;

import java.math.BigDecimal;

public record AtmRetiroResponse(
        Long cuentaId,
        BigDecimal montoRetirado,
        BigDecimal saldoDisponible
) {
    // Mantengo la respuesta del ATM deliberadamente pequeña: solo devuelvo lo necesario después del retiro.
}
