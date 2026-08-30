package cl.duoc.bancoxyzbatch.config;

import org.springframework.batch.core.configuration.annotation.EnableBatchProcessing;
import org.springframework.batch.core.configuration.annotation.EnableJdbcJobRepository;
import org.springframework.context.annotation.Configuration;

/**
 * Configuro Spring Batch utilizando un JobRepository persistente en PostgreSQL.
 * Esto permite conservar metadatos de ejecución y trabajar de forma segura
 * con los procesos concurrentes utilizados durante esta evaluación.
 */
@Configuration
@EnableBatchProcessing
@EnableJdbcJobRepository
public class BatchInfrastructureConfig {

    /*
     * Spring utiliza automáticamente el DataSource y el TransactionManager
     * configurados por Spring Boot para persistir los metadatos del batch.
     */
}
