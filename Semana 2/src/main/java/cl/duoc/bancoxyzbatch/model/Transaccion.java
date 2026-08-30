package cl.duoc.bancoxyzbatch.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Transaccion {

    private Long id;
    private LocalDate fecha;
    private BigDecimal monto;
    private String tipo;
}
