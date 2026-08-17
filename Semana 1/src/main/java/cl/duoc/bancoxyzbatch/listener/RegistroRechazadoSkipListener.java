package cl.duoc.bancoxyzbatch.listener;

import cl.duoc.bancoxyzbatch.model.RegistroRechazado;
import cl.duoc.bancoxyzbatch.repository.RegistroRechazadoRepository;
import org.springframework.batch.core.listener.SkipListener;
import org.springframework.batch.core.scope.context.StepSynchronizationManager;
import org.springframework.batch.infrastructure.item.file.FlatFileParseException;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

@Component
public class RegistroRechazadoSkipListener<I, O>
        implements SkipListener<I, O> {

    private final RegistroRechazadoRepository repository;

    public RegistroRechazadoSkipListener(
            RegistroRechazadoRepository repository
    ) {
        this.repository = repository;
    }

    @Override
    public void onSkipInRead(Throwable throwable) {
        RegistroRechazado registro = crearRegistroBase(
                "READ",
                throwable
        );

        if (throwable instanceof FlatFileParseException parseException) {
            registro.setNumeroLinea((long) parseException.getLineNumber());
            registro.setContenidoOriginal(parseException.getInput());
        }

        repository.save(registro);
    }

    @Override
    public void onSkipInProcess(I item, Throwable throwable) {
        RegistroRechazado registro = crearRegistroBase(
                "PROCESS",
                throwable
        );

        registro.setContenidoOriginal(
                item != null ? item.toString() : null
        );

        repository.save(registro);
    }

    @Override
    public void onSkipInWrite(O item, Throwable throwable) {
        RegistroRechazado registro = crearRegistroBase(
                "WRITE",
                throwable
        );

        registro.setContenidoOriginal(
                item != null ? item.toString() : null
        );

        repository.save(registro);
    }

    private RegistroRechazado crearRegistroBase(
            String fase,
            Throwable throwable
    ) {
        RegistroRechazado registro = new RegistroRechazado();

        var context = StepSynchronizationManager.getContext();

        if (context != null) {
            var stepExecution = context.getStepExecution();

            registro.setStepName(stepExecution.getStepName());
            registro.setJobName(
                    stepExecution
                            .getJobExecution()
                            .getJobInstance()
                            .getJobName()
            );
            registro.setJobInstanceId(
                    stepExecution
                            .getJobExecution()
                            .getJobInstance()
                            .getId()
            );
        } else {
            registro.setStepName("DESCONOCIDO");
            registro.setJobName("DESCONOCIDO");
        }

        registro.setFase(fase);

        registro.setTipoError(
                throwable != null
                        ? throwable.getClass().getSimpleName()
                        : "ErrorDesconocido"
        );

        registro.setMensajeError(
                throwable != null
                        ? throwable.getMessage()
                        : "Sin detalle disponible"
        );

        registro.setFechaRegistro(LocalDateTime.now());

        return registro;
    }
}
