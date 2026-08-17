package cl.duoc.bancoxyzbatch.job;

import cl.duoc.bancoxyzbatch.listener.RegistroRechazadoSkipListener;
import cl.duoc.bancoxyzbatch.model.Transaccion;
import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;
import cl.duoc.bancoxyzbatch.processor.TransaccionProcessor;
import cl.duoc.bancoxyzbatch.tasklet.ResumenTransaccionDiariaTasklet;
import cl.duoc.bancoxyzbatch.tasklet.TransaccionReconciliationTasklet;
import cl.duoc.bancoxyzbatch.writer.TransaccionWriter;
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
public class TransaccionJobConfig {

    @Bean
    public Step transaccionStep(
            JobRepository jobRepository,
            FlatFileItemReader<Transaccion> transaccionReader,
            TransaccionProcessor transaccionProcessor,
            TransaccionWriter transaccionWriter,
            RegistroRechazadoSkipListener<Transaccion, TransaccionProcesada> registroRechazadoSkipListener
    ) {

        return new StepBuilder(
                "transaccionStep",
                jobRepository
        )
                .<Transaccion, TransaccionProcesada>chunk(10)
                .reader(transaccionReader)
                .processor(transaccionProcessor)
                .writer(transaccionWriter)
                .faultTolerant()
                .skip(FlatFileParseException.class)
                .skipLimit(10)
                .listener(registroRechazadoSkipListener)
                .build();
    }

    @Bean
    public Step transaccionReconciliationStep(
            JobRepository jobRepository,
            TransaccionReconciliationTasklet tasklet
    ) {

        return new StepBuilder(
                "transaccionReconciliationStep",
                jobRepository
        )
                .tasklet(tasklet)
                .build();
    }

    @Bean
    public Step resumenTransaccionDiariaStep(
            JobRepository jobRepository,
            ResumenTransaccionDiariaTasklet tasklet
    ) {

        return new StepBuilder(
                "resumenTransaccionDiariaStep",
                jobRepository
        )
                .tasklet(tasklet)
                .build();
    }

    @Bean
    public Job transaccionJob(
            JobRepository jobRepository,
            Step transaccionStep,
            Step transaccionReconciliationStep,
            Step resumenTransaccionDiariaStep
    ) {

        return new JobBuilder(
                "transaccionJob",
                jobRepository
        )
                .start(transaccionStep)
                .next(transaccionReconciliationStep)
                .next(resumenTransaccionDiariaStep)
                .build();
    }
}
