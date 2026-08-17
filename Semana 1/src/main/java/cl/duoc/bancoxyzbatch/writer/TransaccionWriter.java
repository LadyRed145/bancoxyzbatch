package cl.duoc.bancoxyzbatch.writer;

import cl.duoc.bancoxyzbatch.config.BatchRunContext;
import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;
import cl.duoc.bancoxyzbatch.repository.TransaccionProcesadaRepository;
import org.springframework.batch.infrastructure.item.Chunk;
import org.springframework.batch.infrastructure.item.ItemWriter;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Component
public class TransaccionWriter
        implements ItemWriter<TransaccionProcesada> {

    private final TransaccionProcesadaRepository repository;
    private final BatchRunContext runContext;

    /*
     * Guarda la primera transacción encontrada por combinación
     * fecha + monto + tipo durante una JobInstance.
     *
     * Permite detectar registros distintos que representan
     * aparentemente la misma operación financiera.
     */
    private final Map<String, Long> primeraTransaccionPorClave =
            new HashMap<>();

    private Long jobInstanceEnMemoria;

    public TransaccionWriter(
            TransaccionProcesadaRepository repository,
            BatchRunContext runContext
    ) {
        this.repository = repository;
        this.runContext = runContext;
    }

    @Override
    public void write(
            Chunk<? extends TransaccionProcesada> chunk
    ) {

        if (chunk.isEmpty()) {
            return;
        }

        Long jobInstanceId =
                runContext.getJobInstanceId();

        /*
         * El Writer es un componente singleton.
         * Si comienza una nueva JobInstance se limpia el estado
         * utilizado para detectar duplicados de la ejecución anterior.
         */
        prepararContexto(jobInstanceId);

        List<TransaccionProcesada> transacciones =
                new ArrayList<>();

        for (TransaccionProcesada transaccion : chunk) {

            detectarDuplicado(transaccion);

            transaccion.setActivo(true);
            transaccion.setUltimaInstanciaId(
                    jobInstanceId
            );

            transacciones.add(transaccion);
        }

        repository.saveAll(transacciones);
    }

    private void prepararContexto(Long jobInstanceId) {

        if (jobInstanceEnMemoria == null
                || !jobInstanceEnMemoria.equals(jobInstanceId)) {

            primeraTransaccionPorClave.clear();
            jobInstanceEnMemoria = jobInstanceId;
        }
    }

    private void detectarDuplicado(
            TransaccionProcesada transaccion
    ) {

        /*
         * No analizamos como duplicados registros que ya fueron
         * rechazados por una regla de negocio.
         */
        if ("RECHAZADO".equals(transaccion.getEstado())) {
            return;
        }

        if (transaccion.getFecha() == null
                || transaccion.getMonto() == null
                || transaccion.getTipo() == null
                || transaccion.getTipo().isBlank()) {

            return;
        }

        String clave = construirClave(transaccion);

        Long primeraId =
                primeraTransaccionPorClave.get(clave);

        if (primeraId != null
                && !primeraId.equals(transaccion.getId())) {

            transaccion.setEstado("DUPLICADO");
            transaccion.setObservacion(
                    "Posible duplicado de contenido. "
                            + "Coincide con la transacción ID "
                            + primeraId
            );

            return;
        }

        primeraTransaccionPorClave.put(
                clave,
                transaccion.getId()
        );
    }

    private String construirClave(
            TransaccionProcesada transaccion
    ) {

        BigDecimal montoNormalizado =
                transaccion.getMonto()
                        .stripTrailingZeros();

        return transaccion.getFecha()
                + "|"
                + montoNormalizado.toPlainString()
                + "|"
                + transaccion.getTipo();
    }
}
