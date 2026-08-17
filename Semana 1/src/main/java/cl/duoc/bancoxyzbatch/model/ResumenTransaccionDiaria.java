package cl.duoc.bancoxyzbatch.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "resumen_transacciones_diarias")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ResumenTransaccionDiaria {

    @Id
    private LocalDate fecha;

    @Column(name = "cantidad_transacciones", nullable = false)
    private Long cantidadTransacciones;

    @Column(name = "total_creditos", nullable = false, precision = 19, scale = 2)
    private BigDecimal totalCreditos;

    @Column(name = "total_debitos", nullable = false, precision = 19, scale = 2)
    private BigDecimal totalDebitos;

    @Column(name = "saldo_neto", nullable = false, precision = 19, scale = 2)
    private BigDecimal saldoNeto;

    @Column(name = "ultima_instancia_id")
    private Long ultimaInstanciaId;
}
