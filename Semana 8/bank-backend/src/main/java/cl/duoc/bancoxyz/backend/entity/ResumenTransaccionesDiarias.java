package cl.duoc.bancoxyz.backend.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "resumen_transacciones_diarias")
public class ResumenTransaccionesDiarias {

    @Id
    private LocalDate fecha;

    @Column(name = "cantidad_transacciones", nullable = false)
    private Long cantidadTransacciones;

    @Column(name = "saldo_neto", nullable = false)
    private BigDecimal saldoNeto;

    @Column(name = "total_creditos", nullable = false)
    private BigDecimal totalCreditos;

    @Column(name = "total_debitos", nullable = false)
    private BigDecimal totalDebitos;

    @Column(name = "ultima_instancia_id")
    private Long ultimaInstanciaId;

    public LocalDate getFecha() {
        return fecha;
    }

    public Long getCantidadTransacciones() {
        return cantidadTransacciones;
    }

    public BigDecimal getSaldoNeto() {
        return saldoNeto;
    }

    public BigDecimal getTotalCreditos() {
        return totalCreditos;
    }

    public BigDecimal getTotalDebitos() {
        return totalDebitos;
    }

    public Long getUltimaInstanciaId() {
        return ultimaInstanciaId;
    }
}