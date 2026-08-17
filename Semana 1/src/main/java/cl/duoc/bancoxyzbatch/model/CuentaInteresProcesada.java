package cl.duoc.bancoxyzbatch.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Entity
@Table(name = "cuentas_intereses")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CuentaInteresProcesada {

    @Id
    private Long cuentaId;

    @Column(nullable = false, length = 100)
    private String nombre;

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal saldoInicial;

    @Column(nullable = false, length = 30)
    private String tipo;

    @Column(nullable = false, precision = 10, scale = 4)
    private BigDecimal tasaInteres;

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal interesCalculado;

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal saldoFinal;

    @Column(nullable = false, length = 30)
    private String estado;

    @Column(length = 255)
    private String observacion;

    @Column(nullable = false)
    private boolean activo = true;

    @Column(name = "ultima_instancia_id")
    private Long ultimaInstanciaId;
}
