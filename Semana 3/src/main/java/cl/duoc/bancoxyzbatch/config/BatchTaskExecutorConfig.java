package cl.duoc.bancoxyzbatch.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * Configuro el pool de hilos utilizado por los Steps.
 * Externalizo sus valores para poder comparar distintas configuraciones.
 */
@Configuration
public class BatchTaskExecutorConfig {

    @Bean(name = "batchTaskExecutor")
    public AsyncTaskExecutor batchTaskExecutor(
            @Value("${app.batch.threads:3}") int threads,
            @Value("${app.batch.queue-capacity:20}") int queueCapacity
    ) {

        if (threads < 1) {
            throw new IllegalArgumentException(
                    "app.batch.threads debe ser mayor o igual a 1"
            );
        }

        if (queueCapacity < 0) {
            throw new IllegalArgumentException(
                    "app.batch.queue-capacity no puede ser negativo"
            );
        }

        /*
         * Mantengo el mínimo y máximo iguales para que cada
         * prueba de rendimiento tenga un número fijo de hilos.
         */
        ThreadPoolTaskExecutor executor =
                new ThreadPoolTaskExecutor();

        executor.setCorePoolSize(threads);
        executor.setMaxPoolSize(threads);
        executor.setQueueCapacity(queueCapacity);

        executor.setThreadNamePrefix(
                "batch-thread-"
        );

        executor.setWaitForTasksToCompleteOnShutdown(
                true
        );

        executor.setAwaitTerminationMillis(
                30_000
        );

        executor.initialize();

        System.out.println(
                "[BATCH-CONFIG] threads="
                        + threads
                        + " | queueCapacity="
                        + queueCapacity
        );

        return executor;
    }
}
