package cl.duoc.bancoxyzbatch.job;

import cl.duoc.bancoxyzbatch.exception.ReglaNegocioException;
import cl.duoc.bancoxyzbatch.listener.RegistroRechazadoSkipListener;
import cl.duoc.bancoxyzbatch.model.MovimientoAnual;
import cl.duoc.bancoxyzbatch.processor.MovimientoAnualProcessor;
import cl.duoc.bancoxyzbatch.tasklet.EstadoCuentaAnualReconciliationTasklet;
import cl.duoc.bancoxyzbatch.writer.EstadoCuentaAnualWriter;

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
 * Defino el Job que consolida los movimientos anuales.
 * Incluyo retry, skip controlado y procesamiento paralelo.
 */
@Configuration
public class EstadoCuentaAnualJobConfig {

    @Bean
    public Step estadoCuentaAnualStep(
            JobRepository jobRepository,
            PlatformTransactionManager transactionManager,

            @Qualifier("movimientoAnualReader")
            ItemStreamReader<MovimientoAnual> movimientoAnualReader,

            MovimientoAnualProcessor movimientoAnualProcessor,
            EstadoCuentaAnualWriter estadoCuentaAnualWriter,

            RegistroRechazadoSkipListener<
                    MovimientoAnual,
                    MovimientoAnual
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
                "estadoCuentaAnualStep",
                jobRepository
        )
                .<MovimientoAnual, MovimientoAnual>
                        chunk(chunkSize)

                .transactionManager(
                        transactionManager
                )

                .reader(
                        movimientoAnualReader
                )

                .processor(
                        movimientoAnualProcessor
                )

                .writer(
                        estadoCuentaAnualWriter
                )

                /*
                 * Los fallos transitorios se reintentan.
                 * Los errores de formato o negocio se registran y omiten.
                 */
                .faultTolerant()

                .retryPolicy(
                        batchRetryPolicy
                )

                .skip(
                        FlatFileParseException.class,
                        ReglaNegocioException.class
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
                .start(
                        estadoCuentaAnualStep
                )

                .next(
                        estadoCuentaAnualReconciliationStep
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
