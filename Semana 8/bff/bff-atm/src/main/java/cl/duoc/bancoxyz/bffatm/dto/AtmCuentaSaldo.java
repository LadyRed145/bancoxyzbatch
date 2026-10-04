package cl.duoc.bancoxyz.bffatm.dto;

import java.math.BigDecimal;

public record AtmCuentaSaldo(
        Long cuentaId,
        String nombre,
        BigDecimal saldoDisponible
) {
}