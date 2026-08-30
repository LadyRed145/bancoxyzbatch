package cl.duoc.bancoxyzbatch.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

@Configuration
public class BatchTaskExecutorConfig {

    @Bean(name = "batchTaskExecutor")
    public AsyncTaskExecutor batchTaskExecutor() {

        ThreadPoolTaskExecutor executor =
                new ThreadPoolTaskExecutor();

        // Requisito de la actividad:
        // 3 hilos de ejecución paralela.
        executor.setCorePoolSize(3);
        executor.setMaxPoolSize(3);

        // Permite mantener tareas pendientes
        // cuando los 3 hilos están ocupados.
        executor.setQueueCapacity(10);

        // Nombre identificable para las evidencias
        // de ejecución y depuración.
        executor.setThreadNamePrefix("batch-thread-");

        executor.initialize();

        return executor;
    }
}