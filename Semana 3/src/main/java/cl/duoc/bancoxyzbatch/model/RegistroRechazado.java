package cl.duoc.bancoxyzbatch.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "registros_rechazados")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RegistroRechazado {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "job_name", nullable = false, length = 100)
    private String jobName;

    @Column(name = "step_name", nullable = false, length = 100)
    private String stepName;

    @Column(nullable = false, length = 30)
    private String fase;

    @Column(name = "numero_linea")
    private Long numeroLinea;

    @Column(name = "contenido_original", length = 2000)
    private String contenidoOriginal;

    @Column(name = "tipo_error", nullable = false, length = 255)
    private String tipoError;

    @Column(name = "mensaje_error", length = 2000)
    private String mensajeError;

    @Column(name = "job_instance_id")
    private Long jobInstanceId;

    @Column(name = "fecha_registro", nullable = false)
    private LocalDateTime fechaRegistro;
}
