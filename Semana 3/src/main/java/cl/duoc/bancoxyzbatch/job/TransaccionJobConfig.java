package cl.duoc.bancoxyzbatch.job;

import cl.duoc.bancoxyzbatch.listener.RegistroRechazadoSkipListener;
import cl.duoc.bancoxyzbatch.model.Transaccion;
import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;
import cl.duoc.bancoxyzbatch.processor.TransaccionProcessor;
import cl.duoc.bancoxyzbatch.tasklet.ResumenTransaccionDiariaTasklet;
import cl.duoc.bancoxyzbatch.tasklet.TransaccionDuplicadosTasklet;
import cl.duoc.bancoxyzbatch.tasklet.TransaccionReconciliationTasklet;
import cl.duoc.bancoxyzbatch.writer.TransaccionWriter;

import org.springframework.batch.core.job.Job;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.step.Step;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.batch.infrastructure.item.ItemStreamReader;
import org.springframework.batch.infrastructure.item.file.FlatFileParseException;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.retry.RetryPolicy;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * Defino el flujo completo del procesamiento de transacciones.
 * El Step principal incorpora paralelismo, retry y tolerancia a fallos.
 */
@Configuration
public class TransaccionJobConfig {

    @Bean
    public Step transaccionStep(
            JobRepository jobRepository,
            PlatformTransactionManager transactionManager,

            @Qualifier("transaccionReader")
            ItemStreamReader<Transaccion> transaccionReader,

            TransaccionProcessor transaccionProcessor,
            TransaccionWriter transaccionWriter,

            RegistroRechazadoSkipListener<
                    Transaccion,
                    TransaccionProcesada
                    > registroRechazadoSkipListener,

            @Qualifier("batchTaskExecutor")
            AsyncTaskExecutor batchTaskExecutor,

            @Qualifier("batchRetryPolicy")
            RetryPolicy batchRetryPolicy,

            @Value("${app.batch.chunk-size:5}")
            int chunkSize
    ) {

        validarChunkSize(chunkSize);

        return new StepBuilder(
                "transaccionStep",
                jobRepository
        )
                .<Transaccion, TransaccionProcesada>
                        chunk(chunkSize)

                .transactionManager(
                        transactionManager
                )

                .reader(
                        transaccionReader
                )

                .processor(
                        transaccionProcessor
                )

                .writer(
                        transaccionWriter
                )

                /*
                 * Reintento fallos transitorios y omito únicamente
                 * errores controlados durante la lectura del CSV.
                 */
                .faultTolerant()

                .retryPolicy(
                        batchRetryPolicy
                )

                .skip(
                        FlatFileParseException.class
                )

                .skipLimit(10)

                .skipListener(
                        registroRechazadoSkipListener
                )

                .taskExecutor(
                        batchTaskExecutor
                )

                .build();
    }

    @Bean
    public Step transaccionDuplicadosStep(
            JobRepository jobRepository,
            TransaccionDuplicadosTasklet tasklet
    ) {

        return new StepBuilder(
                "transaccionDuplicadosStep",
                jobRepository
        )
                .tasklet(tasklet)
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
            Step transaccionDuplicadosStep,
            Step transaccionReconciliationStep,
            Step resumenTransaccionDiariaStep
    ) {

        return new JobBuilder(
                "transaccionJob",
                jobRepository
        )
                .start(
                        transaccionStep
                )
                .next(
                        transaccionDuplicadosStep
                )
                .next(
                        transaccionReconciliationStep
                )
                .next(
                        resumenTransaccionDiariaStep
                )
                .build();
    }

    /**
     * Evito construir un Step con un tamaño de chunk inválido.
     */
    private void validarChunkSize(
            int chunkSize
    ) {

        if (chunkSize < 1) {

            throw new IllegalArgumentException(
                    "app.batch.chunk-size debe ser mayor o igual a 1"
            );
        }
    }
}
