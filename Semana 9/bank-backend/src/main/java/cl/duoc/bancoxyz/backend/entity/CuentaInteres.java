package cl.duoc.bancoxyz.backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;

@Entity
@Table(name = "cuentas_intereses")
public class CuentaInteres {

    @Id
    @Column(name = "cuenta_id")
    private Long cuentaId;

    @Column(nullable = false)
    private Boolean activo;

    @Column(nullable = false, length = 30)
    private String estado;

    @Column(name = "interes_calculado", nullable = false)
    private BigDecimal interesCalculado;

    @Column(nullable = false, length = 100)
    private String nombre;

    @Column(length = 255)
    private String observacion;

    @Column(name = "saldo_final", nullable = false)
    private BigDecimal saldoFinal;

    @Column(name = "saldo_inicial", nullable = false)
    private BigDecimal saldoInicial;

    @Column(name = "tasa_interes", nullable = false)
    private BigDecimal tasaInteres;

    @Column(nullable = false, length = 30)
    private String tipo;

    @Column(name = "ultima_instancia_id")
    private Long ultimaInstanciaId;

    public Long getCuentaId() {
        return cuentaId;
    }

    public void setCuentaId(Long cuentaId) {
        this.cuentaId = cuentaId;
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

    public BigDecimal getInteresCalculado() {
        return interesCalculado;
    }

    public void setInteresCalculado(BigDecimal interesCalculado) {
        this.interesCalculado = interesCalculado;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getObservacion() {
        return observacion;
    }

    public void setObservacion(String observacion) {
        this.observacion = observacion;
    }

    public BigDecimal getSaldoFinal() {
        return saldoFinal;
    }

    public void setSaldoFinal(BigDecimal saldoFinal) {
        this.saldoFinal = saldoFinal;
    }

    public BigDecimal getSaldoInicial() {
        return saldoInicial;
    }

    public void setSaldoInicial(BigDecimal saldoInicial) {
        this.saldoInicial = saldoInicial;
    }

    public BigDecimal getTasaInteres() {
        return tasaInteres;
    }

    public void setTasaInteres(BigDecimal tasaInteres) {
        this.tasaInteres = tasaInteres;
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