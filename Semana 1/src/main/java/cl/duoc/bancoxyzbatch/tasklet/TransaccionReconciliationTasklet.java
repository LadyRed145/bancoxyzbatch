package cl.duoc.bancoxyzbatch.tasklet;

import cl.duoc.bancoxyzbatch.repository.TransaccionProcesadaRepository;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.StepContribution;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.infrastructure.repeat.RepeatStatus;
import org.springframework.stereotype.Component;

@Component
public class TransaccionReconciliationTasklet
        implements Tasklet {

    private final TransaccionProcesadaRepository repository;

    public TransaccionReconciliationTasklet(
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

        repository.marcarInactivosNoVistos(
                jobInstanceId
        );

        return RepeatStatus.FINISHED;
    }
}
