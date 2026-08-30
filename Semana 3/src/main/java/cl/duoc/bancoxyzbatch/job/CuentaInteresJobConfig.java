package cl.duoc.bancoxyzbatch.job;

import cl.duoc.bancoxyzbatch.listener.RegistroRechazadoSkipListener;
import cl.duoc.bancoxyzbatch.model.CuentaInteres;
import cl.duoc.bancoxyzbatch.model.CuentaInteresProcesada;
import cl.duoc.bancoxyzbatch.processor.CuentaInteresProcessor;
import cl.duoc.bancoxyzbatch.tasklet.CuentaInteresReconciliationTasklet;
import cl.duoc.bancoxyzbatch.writer.CuentaInteresWriter;

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
 * Defino el Job encargado del cálculo mensual de intereses.
 * Utilizo procesamiento paralelo, retry y tolerancia a errores del CSV.
 */
@Configuration
public class CuentaInteresJobConfig {

    @Bean
    public Step cuentaInteresStep(
            JobRepository jobRepository,
            PlatformTransactionManager transactionManager,

            @Qualifier("cuentaInteresReader")
            ItemStreamReader<CuentaInteres> cuentaInteresReader,

            CuentaInteresProcessor cuentaInteresProcessor,
            CuentaInteresWriter cuentaInteresWriter,

            RegistroRechazadoSkipListener<
                    CuentaInteres,
                    CuentaInteresProcesada
                    > registroRechazadoSkipListener,

            @Qualifier("batchTaskExecutor")
            AsyncTaskExecutor batchTaskExecutor,

            @Qualifier("batchRetryPolicy")
            RetryPolicy batchRetryPolicy,

            @Value("${app.batch.chunk-size:5}")
            int chunkSize
    ) {

        validarChunkSize(
                chunkSize
        );

        return new StepBuilder(
                "cuentaInteresStep",
                jobRepository
        )
                .<CuentaInteres, CuentaInteresProcesada>
                        chunk(chunkSize)

                .transactionManager(
                        transactionManager
                )

                .reader(
                        cuentaInteresReader
                )

                .processor(
                        cuentaInteresProcessor
                )

                .writer(
                        cuentaInteresWriter
                )

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
    public Step cuentaInteresReconciliationStep(
            JobRepository jobRepository,
            CuentaInteresReconciliationTasklet tasklet
    ) {

        return new StepBuilder(
                "cuentaInteresReconciliationStep",
                jobRepository
        )
                .tasklet(tasklet)
                .build();
    }

    @Bean
    public Job cuentaInteresJob(
            JobRepository jobRepository,
            Step cuentaInteresStep,
            Step cuentaInteresReconciliationStep
    ) {

        return new JobBuilder(
                "cuentaInteresJob",
                jobRepository
        )
                .start(
                        cuentaInteresStep
                )

                .next(
                        cuentaInteresReconciliationStep
                )

                .build();
    }

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
