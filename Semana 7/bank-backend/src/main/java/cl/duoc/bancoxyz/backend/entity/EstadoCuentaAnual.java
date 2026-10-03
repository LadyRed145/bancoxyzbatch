package cl.duoc.bancoxyz.backend.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;

@Entity
@Table(name = "estados_cuenta_anuales")
public class EstadoCuentaAnual {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Boolean activo;

    @Column(nullable = false)
    private Integer anio;

    @Column(name = "cuenta_id", nullable = false)
    private Long cuentaId;

    @Column(name = "saldo_anual", nullable = false)
    private BigDecimal saldoAnual;

    @Column(name = "total_compras", nullable = false)
    private BigDecimal totalCompras;

    @Column(name = "total_depositos", nullable = false)
    private BigDecimal totalDepositos;

    @Column(name = "total_retiros", nullable = false)
    private BigDecimal totalRetiros;

    @Column(name = "ultima_instancia_id")
    private Long ultimaInstanciaId;

    public Long getId() {
        return id;
    }

    public Boolean getActivo() {
        return activo;
    }

    public Integer getAnio() {
        return anio;
    }

    public Long getCuentaId() {
        return cuentaId;
    }

    public BigDecimal getSaldoAnual() {
        return saldoAnual;
    }

    public BigDecimal getTotalCompras() {
        return totalCompras;
    }

    public BigDecimal getTotalDepositos() {
        return totalDepositos;
    }

    public BigDecimal getTotalRetiros() {
        return totalRetiros;
    }

    public Long getUltimaInstanciaId() {
        return ultimaInstanciaId;
    }
}
