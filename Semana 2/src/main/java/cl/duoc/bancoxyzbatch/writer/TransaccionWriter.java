package cl.duoc.bancoxyzbatch.writer;

import cl.duoc.bancoxyzbatch.config.BatchRunContext;
import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;
import cl.duoc.bancoxyzbatch.repository.TransaccionProcesadaRepository;
import org.springframework.batch.infrastructure.item.Chunk;
import org.springframework.batch.infrastructure.item.ItemWriter;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

@Component
public class TransaccionWriter
        implements ItemWriter<TransaccionProcesada> {

    private final TransaccionProcesadaRepository repository;
    private final BatchRunContext runContext;

    /*
     * Registro de la primera transacción encontrada
     * por combinación:
     *
     * fecha + monto + tipo
     *
     * Se utiliza ConcurrentHashMap porque el Step puede
     * ejecutar varios chunks simultáneamente mediante
     * los 3 hilos configurados.
     */
    private final ConcurrentMap<String, Long> primeraTransaccionPorClave =
            new ConcurrentHashMap<>();

    /*
     * Identifica la JobInstance actualmente procesada.
     *
     * volatile garantiza que los diferentes hilos
     * puedan visualizar correctamente el valor actualizado.
     */
    private volatile Long jobInstanceEnMemoria;

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

        /*
         * Evidencia del hilo que está ejecutando el Writer.
         */
        System.out.println(
                "[BATCH-WRITER] hilo="
                        + Thread.currentThread().getName()
                        + " | chunk="
                        + chunk.size()
                        + " | jobInstance="
                        + runContext.getJobInstanceId()
        );

        Long jobInstanceId =
                runContext.getJobInstanceId();

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

    /*
     * Prepara el contexto de memoria para la JobInstance actual.
     */
    private synchronized void prepararContexto(
            Long jobInstanceId
    ) {

        if (jobInstanceEnMemoria == null
                || !jobInstanceEnMemoria.equals(jobInstanceId)) {

            primeraTransaccionPorClave.clear();

            jobInstanceEnMemoria = jobInstanceId;
        }
    }

    /*
     * Detecta posibles transacciones duplicadas.
     */
    private void detectarDuplicado(
            TransaccionProcesada transaccion
    ) {

        /*
         * Los registros rechazados no participan
         * en la detección de duplicados.
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

        String clave =
                construirClave(transaccion);

        /*
         putIfAbsent realiza la operación de forma atómica.

         Si no existe una transacción con esta clave,
         registra la actual como primera.

         Si ya existe, devuelve el ID de la primera.
         */
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
        }
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