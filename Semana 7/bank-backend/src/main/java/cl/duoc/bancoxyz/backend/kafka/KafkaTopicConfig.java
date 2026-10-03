package cl.duoc.bancoxyz.backend.kafka;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class KafkaTopicConfig {

    @Bean
    public NewTopic retirosTopic() {
        return new NewTopic("bancoxyz.retiros", 1, (short) 1);
    }
}