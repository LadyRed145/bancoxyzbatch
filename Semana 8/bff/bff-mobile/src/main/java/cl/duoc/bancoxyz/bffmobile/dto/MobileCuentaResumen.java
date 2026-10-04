package cl.duoc.bancoxyz.bffmobile.dto;

import java.math.BigDecimal;

public record MobileCuentaResumen(
        Long cuentaId,
        String nombre,
        String tipo,
        String estado,
        BigDecimal saldoFinal
) {
}