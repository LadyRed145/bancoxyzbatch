package cl.duoc.bancoxyzbatch.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "transacciones_procesadas")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class TransaccionProcesada {

    @Id
    private Long id;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal monto;

    @Column(nullable = false, length = 30)
    private String tipo;

    @Column(nullable = false, length = 30)
    private String estado;

    @Column(length = 255)
    private String observacion;

    @Column(nullable = false)
    private boolean activo = true;

    @Column(name = "ultima_instancia_id")
    private Long ultimaInstanciaId;
}
