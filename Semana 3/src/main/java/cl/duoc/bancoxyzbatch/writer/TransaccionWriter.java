package cl.duoc.bancoxyzbatch.writer;

import cl.duoc.bancoxyzbatch.config.BatchRunContext;
import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;
import cl.duoc.bancoxyzbatch.repository.TransaccionProcesadaRepository;

import org.springframework.batch.infrastructure.item.Chunk;
import org.springframework.batch.infrastructure.item.ItemWriter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.TransientDataAccessResourceException;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Persisto las transacciones procesadas y las asocio a la JobInstance actual.
 * Incluyo un mecanismo desactivado por defecto para validar retry de forma controlada.
 */
@Component
public class TransaccionWriter
        implements ItemWriter<TransaccionProcesada> {

    private final TransaccionProcesadaRepository repository;
    private final BatchRunContext runContext;

    private final int fallosSimuladosConfigurados;
    private final AtomicInteger fallosSimuladosRestantes;
    private final AtomicInteger invocacionesWriter =
            new AtomicInteger(0);

    private final AtomicBoolean recuperacionInformada =
            new AtomicBoolean(false);

    public TransaccionWriter(
            TransaccionProcesadaRepository repository,
            BatchRunContext runContext,

            @Value("${app.batch.retry-demo-failures:0}")
            int retryDemoFailures
    ) {

        if (retryDemoFailures < 0) {
            throw new IllegalArgumentException(
                    "app.batch.retry-demo-failures no puede ser negativo"
            );
        }

        this.repository = repository;
        this.runContext = runContext;

        this.fallosSimuladosConfigurados =
                retryDemoFailures;

        this.fallosSimuladosRestantes =
                new AtomicInteger(retryDemoFailures);

        if (retryDemoFailures > 0) {

            System.out.println(
                    "[BATCH-RETRY-DEMO] ACTIVADO"
                            + " | fallosSimulados="
                            + retryDemoFailures
            );
        }
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

        int invocacion =
                invocacionesWriter.incrementAndGet();

        /*
         * La simulación ocurre antes de persistir.
         * Así puedo comprobar retry sin dejar escrituras parciales.
         */
        simularFalloTransitorioSiCorresponde(
                jobInstanceId,
                invocacion
        );

        System.out.println(
                "[BATCH-WRITER] hilo="
                        + Thread.currentThread().getName()
                        + " | chunk="
                        + chunk.size()
                        + " | jobInstance="
                        + jobInstanceId
                        + " | invocacion="
                        + invocacion
        );

        List<TransaccionProcesada> transacciones =
                new ArrayList<>();

        for (TransaccionProcesada transaccion : chunk) {

            transaccion.setActivo(true);

            transaccion.setUltimaInstanciaId(
                    jobInstanceId
            );

            transacciones.add(
                    transaccion
            );
        }

        /*
         * Fuerzo el flush dentro del Writer para que cualquier
         * fallo de persistencia sea detectado dentro del Step.
         */
        repository.saveAllAndFlush(
                transacciones
        );
    }

    /**
     * Provoco fallos transitorios únicamente cuando la propiedad
     * de demostración se activa explícitamente desde la terminal.
     */
    private void simularFalloTransitorioSiCorresponde(
            Long jobInstanceId,
            int invocacion
    ) {

        while (true) {

            int restantes =
                    fallosSimuladosRestantes.get();

            if (restantes <= 0) {

                /*
                 * Si ya hubo un fallo y volvimos a entrar al Writer,
                 * significa que Spring Batch ejecutó el reintento.
                 */
                if (fallosSimuladosConfigurados > 0
                        && invocacion > 1
                        && recuperacionInformada.compareAndSet(
                        false,
                        true
                )) {

                    System.out.println(
                            "[BATCH-RETRY-DEMO] RECUPERADO"
                                    + " | invocacionWriter="
                                    + invocacion
                                    + " | jobInstance="
                                    + jobInstanceId
                                    + " | procesamiento continúa"
                    );
                }

                return;
            }

            if (fallosSimuladosRestantes.compareAndSet(
                    restantes,
                    restantes - 1
            )) {

                int numeroFallo =
                        fallosSimuladosConfigurados
                                - restantes
                                + 1;

                System.out.println(
                        "[BATCH-RETRY-DEMO] FALLO_TRANSITORIO"
                                + " | fallo="
                                + numeroFallo
                                + "/"
                                + fallosSimuladosConfigurados
                                + " | invocacionWriter="
                                + invocacion
                                + " | jobInstance="
                                + jobInstanceId
                );

                throw new TransientDataAccessResourceException(
                        "Fallo transitorio simulado para validar "
                                + "la política de retry."
                );
            }
        }
    }
}
