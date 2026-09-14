package cl.duoc.bancoxyz.backend.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "transacciones_procesadas")
public class TransaccionProcesada {

    @Id
    private Long id;

    @Column(nullable = false)
    private Boolean activo;

    @Column(nullable = false, length = 30)
    private String estado;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column(nullable = false)
    private BigDecimal monto;

    @Column(length = 255)
    private String observacion;

    @Column(nullable = false, length = 30)
    private String tipo;

    @Column(name = "ultima_instancia_id")
    private Long ultimaInstanciaId;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Boolean getActivo() {
        return activo;
    }

    public void setActivo(Boolean activo) {
        this.activo = activo;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }

    public LocalDate getFecha() {
        return fecha;
    }

    public void setFecha(LocalDate fecha) {
        this.fecha = fecha;
    }

    public BigDecimal getMonto() {
        return monto;
    }

    public void setMonto(BigDecimal monto) {
        this.monto = monto;
    }

    public String getObservacion() {
        return observacion;
    }

    public void setObservacion(String observacion) {
        this.observacion = observacion;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public Long getUltimaInstanciaId() {
        return ultimaInstanciaId;
    }

    public void setUltimaInstanciaId(Long ultimaInstanciaId) {
        this.ultimaInstanciaId = ultimaInstanciaId;
    }
}