package cl.duoc.bancoxyz.bffweb.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class WebClientConfig {

    @Bean
    public WebClient webClient(
            @Value("${backend.base-url}") String backendBaseUrl) {

        return WebClient.builder()
                .baseUrl(backendBaseUrl)
                .build();
    }
}