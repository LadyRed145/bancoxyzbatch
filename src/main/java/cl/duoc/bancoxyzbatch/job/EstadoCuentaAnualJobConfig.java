package cl.duoc.bancoxyzbatch.job;

import cl.duoc.bancoxyzbatch.listener.RegistroRechazadoSkipListener;
import cl.duoc.bancoxyzbatch.model.MovimientoAnual;
import cl.duoc.bancoxyzbatch.processor.MovimientoAnualProcessor;
import cl.duoc.bancoxyzbatch.tasklet.EstadoCuentaAnualReconciliationTasklet;
import cl.duoc.bancoxyzbatch.writer.EstadoCuentaAnualWriter;
import cl.duoc.bancoxyzbatch.exception.ReglaNegocioException;
import org.springframework.batch.core.job.Job;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.step.Step;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.batch.infrastructure.item.file.FlatFileItemReader;
import org.springframework.batch.infrastructure.item.file.FlatFileParseException;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;


@Configuration
public class EstadoCuentaAnualJobConfig {

    @Bean
    public Step estadoCuentaAnualStep(
            JobRepository jobRepository,
            FlatFileItemReader<MovimientoAnual> movimientoAnualReader,
            MovimientoAnualProcessor movimientoAnualProcessor,
            EstadoCuentaAnualWriter estadoCuentaAnualWriter,
            RegistroRechazadoSkipListener<MovimientoAnual, MovimientoAnual> registroRechazadoSkipListener
    ) {

        return new StepBuilder(
                "estadoCuentaAnualStep",
                jobRepository
        )
                .<MovimientoAnual, MovimientoAnual>chunk(10)
                .reader(movimientoAnualReader)
                .processor(movimientoAnualProcessor)
                .writer(estadoCuentaAnualWriter)

                .faultTolerant()
                .skip(FlatFileParseException.class)
                .skip(ReglaNegocioException.class)
                .skipLimit(10)
                .listener(registroRechazadoSkipListener)

                .build();
    }

    @Bean
    public Step estadoCuentaAnualReconciliationStep(
            JobRepository jobRepository,
            EstadoCuentaAnualReconciliationTasklet tasklet
    ) {

        return new StepBuilder(
                "estadoCuentaAnualReconciliationStep",
                jobRepository
        )
                .tasklet(tasklet)
                .build();
    }

    @Bean
    public Job estadoCuentaAnualJob(
            JobRepository jobRepository,
            Step estadoCuentaAnualStep,
            Step estadoCuentaAnualReconciliationStep
    ) {

        return new JobBuilder(
                "estadoCuentaAnualJob",
                jobRepository
        )
                .start(estadoCuentaAnualStep)
                .next(estadoCuentaAnualReconciliationStep)
                .build();
    }
}
