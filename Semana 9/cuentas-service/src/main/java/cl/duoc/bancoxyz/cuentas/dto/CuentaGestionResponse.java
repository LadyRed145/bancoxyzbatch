package cl.duoc.bancoxyz.cuentas.dto;
import java.math.BigDecimal;
public record CuentaGestionResponse(Long id, String titular, String tipo, String estado, BigDecimal saldoInicial) {}
