package cl.duoc.bancoxyzbatch.writer;

import cl.duoc.bancoxyzbatch.config.BatchRunContext;
import cl.duoc.bancoxyzbatch.model.CuentaInteresProcesada;
import cl.duoc.bancoxyzbatch.repository.CuentaInteresProcesadaRepository;
import org.springframework.batch.infrastructure.item.Chunk;
import org.springframework.batch.infrastructure.item.ItemWriter;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

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

        List<CuentaInteresProcesada> cuentas =
                new ArrayList<>();

        for (CuentaInteresProcesada cuenta : chunk) {

            cuenta.setActivo(true);
            cuenta.setUltimaInstanciaId(
                    runContext.getJobInstanceId()
            );

            cuentas.add(cuenta);
        }

        repository.saveAll(cuentas);
    }
}
