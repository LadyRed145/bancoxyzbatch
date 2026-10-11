package cl.duoc.bancoxyzbatch.writer;

import cl.duoc.bancoxyzbatch.config.BatchRunContext;
import cl.duoc.bancoxyzbatch.model.CuentaInteresProcesada;
import cl.duoc.bancoxyzbatch.repository.CuentaInteresProcesadaRepository;

import org.springframework.batch.infrastructure.item.Chunk;
import org.springframework.batch.infrastructure.item.ItemWriter;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

/**
 * Persisto las cuentas procesadas y registro la JobInstance que las actualizó.
 * El flush permite detectar fallos de persistencia dentro del Writer.
 */
@Component
public class CuentaInteresWriter
        implements ItemWriter<CuentaInteresProcesada> {

    private final CuentaInteresProcesadaRepository repository;
    private final BatchRunContext runContext;

    public CuentaInteresWriter(
            CuentaInteresProcesadaRepository repository,
            BatchRunContext runContext
    ) {
        this.repository = repository;
        this.runContext = runContext;
    }

    @Override
    public void write(
            Chunk<? extends CuentaInteresProcesada> chunk
    ) {

        if (chunk.isEmpty()) {
            return;
        }

        Long jobInstanceId =
                runContext.getJobInstanceId();

        System.out.println(
                "[BATCH-WRITER] hilo="
                        + Thread.currentThread().getName()
                        + " | chunk="
                        + chunk.size()
                        + " | jobInstance="
                        + jobInstanceId
        );

        List<CuentaInteresProcesada> cuentas =
                new ArrayList<>();

        for (CuentaInteresProcesada cuenta :
                chunk) {

            cuenta.setActivo(
                    true
            );

            cuenta.setUltimaInstanciaId(
                    jobInstanceId
            );

            cuentas.add(
                    cuenta
            );
        }

        /*
         * Fuerzo el flush dentro del Writer para que un error
         * transitorio sea capturado por la política de retry.
         */
        repository.saveAllAndFlush(
                cuentas
        );
    }
}
