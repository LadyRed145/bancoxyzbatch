package cl.duoc.bancoxyz.cuentas.entity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
/** Proyeccion de lectura del contrato legacy procesado. No usar para debitar saldos. */
@Entity
@Table(name = "cuentas_intereses")
public class CuentaInteres {
 @Id @Column(name = "cuenta_id") private Long cuentaId;
 @Column(nullable = false) private Boolean activo;
 @Column(nullable = false, length = 30) private String estado;
 @Column(name = "interes_calculado", nullable = false) private BigDecimal interesCalculado;
 @Column(nullable = false, length = 100) private String nombre;
 @Column(length = 255) private String observacion;
 @Column(name = "saldo_final", nullable = false) private BigDecimal saldoFinal;
 @Column(name = "saldo_inicial", nullable = false) private BigDecimal saldoInicial;
 @Column(name = "tasa_interes", nullable = false) private BigDecimal tasaInteres;
 @Column(nullable = false, length = 30) private String tipo;
 @Column(name = "ultima_instancia_id") private Long ultimaInstanciaId;
 public Long getCuentaId() {return cuentaId;}
 public Boolean getActivo() {return activo;}
 public String getEstado() {return estado;}
 public BigDecimal getInteresCalculado() {return interesCalculado;}
 public String getNombre() {return nombre;}
 public String getObservacion() {return observacion;}
 public BigDecimal getSaldoFinal() {return saldoFinal;}
 public BigDecimal getSaldoInicial() {return saldoInicial;}
 public BigDecimal getTasaInteres() {return tasaInteres;}
 public String getTipo() {return tipo;}
 public Long getUltimaInstanciaId() {return ultimaInstanciaId;}
}
