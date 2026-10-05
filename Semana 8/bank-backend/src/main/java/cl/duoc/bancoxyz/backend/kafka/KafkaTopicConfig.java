package cl.duoc.bancoxyz.backend.kafka;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Declara el topic de retiros con la topología exigida para Semana 8:
 * tres particiones y factor de replicación tres.
 */
@Configuration
public class KafkaTopicConfig {

    static final String RETIROS_TOPIC = "bancoxyz.retiros";

    @Bean
    public NewTopic retirosTopic() {
        return new NewTopic(RETIROS_TOPIC, 3, (short) 3);
    }
}
