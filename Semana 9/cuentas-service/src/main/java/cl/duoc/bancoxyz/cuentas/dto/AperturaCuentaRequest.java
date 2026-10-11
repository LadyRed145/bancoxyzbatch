package cl.duoc.bancoxyz.cuentas.dto;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
public record AperturaCuentaRequest(
 @NotBlank @Size(max=100) String titular,
 @NotBlank @Pattern(regexp="AHORRO|CORRIENTE") String tipo,
 @NotNull @DecimalMin("0.00") @Digits(integer=16,fraction=2) BigDecimal saldoInicial
) {}
