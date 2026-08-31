package cl.duoc.bancoxyzbatch.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * Configura el TaskExecutor utilizado por los Jobs
 * que ejecutan chunks en paralelo.
 *
 * La configuración por defecto corresponde al resultado
 * óptimo obtenido mediante benchmarks controlados:
 *
 * threads = 3
 * queue-capacity = 20
 *
 * Los hilos se configuran como daemon para impedir que
 * mantengan viva la JVM una vez que el Job ha terminado.
 */
@Configuration
public class BatchTaskExecutorConfig {

    @Bean(name = "batchTaskExecutor")
    public AsyncTaskExecutor batchTaskExecutor(
            @Value("${app.batch.threads:3}")
            int threads,

            @Value("${app.batch.queue-capacity:20}")
            int queueCapacity
    ) {

        validarConfiguracion(
                threads,
                queueCapacity
        );

        ThreadPoolTaskExecutor executor =
                new ThreadPoolTaskExecutor();

        /*
         * Mantengo la misma cantidad de hilos mínimos
         * y máximos para obtener un comportamiento
         * predecible durante las ejecuciones.
         *
         * El valor por defecto de 3 hilos fue seleccionado
         * mediante benchmarks sobre el dataset actual.
         */
        executor.setCorePoolSize(
                threads
        );

        executor.setMaxPoolSize(
                threads
        );

        /*
         * La capacidad se mantiene en 20.
         *
         * Durante los benchmarks se comprobó que tamaños
         * excesivos de chunk pueden saturar esta cola,
         * permitiendo identificar configuraciones inestables.
         */
        executor.setQueueCapacity(
                queueCapacity
        );

        /*
         * Facilita identificar visualmente qué hilo
         * está procesando cada registro.
         *
         * Ejemplo:
         *
         * batch-thread-1
         * batch-thread-2
         * batch-thread-3
         */
        executor.setThreadNamePrefix(
                "batch-thread-"
        );

        /*
         * Los threads daemon no impiden que la JVM
         * finalice cuando el Job y el hilo principal
         * ya terminaron.
         *
         * Esto evita que las ejecuciones automatizadas
         * y los benchmarks queden bloqueados después
         * de mostrar COMPLETED.
         */
        executor.setDaemon(
                true
        );

        /*
         * Spring Batch espera la finalización de los chunks
         * antes de completar el Step, por lo que no es
         * necesario mantener la JVM bloqueada durante
         * el cierre del executor.
         */
        executor.setWaitForTasksToCompleteOnShutdown(
                false
        );

        System.out.println(
                "[BATCH-CONFIG] threads="
                        + threads
                        + " | queueCapacity="
                        + queueCapacity
                        + " | daemon=true"
        );

        return executor;
    }

    /**
     * Evita iniciar la aplicación con una configuración
     * inválida del pool de threads.
     */
    private void validarConfiguracion(
            int threads,
            int queueCapacity
    ) {

        if (threads < 1) {

            throw new IllegalArgumentException(
                    "app.batch.threads debe ser mayor o igual a 1"
            );
        }

        if (queueCapacity < 0) {

            throw new IllegalArgumentException(
                    "app.batch.queue-capacity debe ser mayor o igual a 0"
            );
        }
    }
}
