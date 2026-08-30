package cl.duoc.bancoxyzbatch.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CuentaInteres {

    private Long cuentaId;
    private String nombre;
    private BigDecimal saldo;
    private Integer edad;
    private String tipo;
}
