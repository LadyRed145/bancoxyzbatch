package cl.duoc.bancoxyzbatch.tasklet;

import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;
import cl.duoc.bancoxyzbatch.repository.TransaccionProcesadaRepository;

import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.StepContribution;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.infrastructure.repeat.RepeatStatus;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Detecto duplicados después del procesamiento paralelo.
 * De esta forma el resultado no depende del orden de ejecución de los hilos.
 */
@Component
public class TransaccionDuplicadosTasklet implements Tasklet {

    private final TransaccionProcesadaRepository repository;

    public TransaccionDuplicadosTasklet(
            TransaccionProcesadaRepository repository
    ) {
        this.repository = repository;
    }

    @Override
    public RepeatStatus execute(
            StepContribution contribution,
            ChunkContext chunkContext
    ) {

        Long jobInstanceId =
                chunkContext
                        .getStepContext()
                        .getJobInstanceId();

        List<TransaccionProcesada> transacciones =
                repository
                        .findByUltimaInstanciaIdOrderByFechaAscIdAsc(
                                jobInstanceId
                        );

        /*
         * Mantengo la primera transacción encontrada para cada combinación.
         * Las apariciones posteriores se consideran duplicadas.
         */
        Map<String, Long> primeraTransaccionPorClave =
                new HashMap<>();

        int duplicados = 0;

        for (TransaccionProcesada transaccion : transacciones) {

            // Los registros rechazados no participan en la detección.
            if ("RECHAZADO".equals(transaccion.getEstado())) {
                continue;
            }

            if (transaccion.getFecha() == null
                    || transaccion.getMonto() == null
                    || transaccion.getTipo() == null
                    || transaccion.getTipo().isBlank()) {

                continue;
            }

            String clave =
                    construirClave(transaccion);

            Long primeraId =
                    primeraTransaccionPorClave.putIfAbsent(
                            clave,
                            transaccion.getId()
                    );

            if (primeraId != null
                    && !primeraId.equals(transaccion.getId())) {

                transaccion.setEstado("DUPLICADO");

                transaccion.setObservacion(
                        "Posible duplicado de contenido. "
                                + "Coincide con la transacción ID "
                                + primeraId
                );

                duplicados++;
            }
        }

        repository.saveAllAndFlush(transacciones);

        System.out.println(
                "[BATCH-DUPLICADOS] jobInstance="
                        + jobInstanceId
                        + " | duplicados="
                        + duplicados
        );

        return RepeatStatus.FINISHED;
    }

    /**
     * Genero una clave estable usando los campos que determinan
     * si dos transacciones representan el mismo movimiento.
     */
    private String construirClave(
            TransaccionProcesada transaccion
    ) {

        BigDecimal montoNormalizado =
                transaccion
                        .getMonto()
                        .stripTrailingZeros();

        return transaccion.getFecha()
                + "|"
                + montoNormalizado.toPlainString()
                + "|"
                + transaccion.getTipo();
    }
}
