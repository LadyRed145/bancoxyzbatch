package cl.duoc.bancoxyzbatch.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Entity
@Table(
        name = "estados_cuenta_anuales",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_estado_cuenta_anio",
                        columnNames = {"cuenta_id", "anio"}
                )
        }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class EstadoCuentaAnual {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "cuenta_id", nullable = false)
    private Long cuentaId;

    @Column(nullable = false)
    private Integer anio;

    @Column(
            name = "total_depositos",
            nullable = false,
            precision = 19,
            scale = 2
    )
    private BigDecimal totalDepositos;

    @Column(
            name = "total_retiros",
            nullable = false,
            precision = 19,
            scale = 2
    )
    private BigDecimal totalRetiros;

    @Column(
            name = "total_compras",
            nullable = false,
            precision = 19,
            scale = 2
    )
    private BigDecimal totalCompras;

    @Column(
            name = "saldo_anual",
            nullable = false,
            precision = 19,
            scale = 2
    )
    private BigDecimal saldoAnual;

    @Column(nullable = false)
    private boolean activo = true;

    @Column(name = "ultima_instancia_id")
    private Long ultimaInstanciaId;
}
