package cl.duoc.bancoxyzbatch.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.retry.RetryPolicy;
import org.springframework.dao.RecoverableDataAccessException;
import org.springframework.dao.TransientDataAccessException;

import java.time.Duration;

/**
 * Configuro una política común de reintento para los procesos batch.
 * Los parámetros quedan externalizados para poder ajustarlos sin modificar código.
 */
@Configuration
public class BatchRetryConfig {

    @Bean(name = "batchRetryPolicy")
    public RetryPolicy batchRetryPolicy(
            @Value("${app.batch.retry-max-retries:3}") long maxRetries,
            @Value("${app.batch.retry-delay-ms:500}") long delayMs
    ) {

        // Valido la configuración al iniciar para evitar parámetros inválidos.
        if (maxRetries < 0) {
            throw new IllegalArgumentException(
                    "app.batch.retry-max-retries no puede ser negativo"
            );
        }

        if (delayMs < 0) {
            throw new IllegalArgumentException(
                    "app.batch.retry-delay-ms no puede ser negativo"
            );
        }

        RetryPolicy retryPolicy = RetryPolicy.builder()
                .maxRetries(maxRetries)
                .delay(Duration.ofMillis(delayMs))
                .includes(
                        TransientDataAccessException.class,
                        RecoverableDataAccessException.class
                )
                .build();

        System.out.println(
                "[BATCH-CONFIG] retryMaxRetries="
                        + maxRetries
                        + " | retryDelayMs="
                        + delayMs
        );

        return retryPolicy;
    }
}
