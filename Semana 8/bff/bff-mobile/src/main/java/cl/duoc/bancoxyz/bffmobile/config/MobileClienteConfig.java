package cl.duoc.bancoxyz.bffmobile.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

/**
 * Configuración del cliente HTTP utilizado por BFF Mobile.
 *
 * Spring Cloud LoadBalancer permite resolver el nombre lógico
 * de bank-backend mediante Eureka, evitando depender de
 * una dirección física como localhost:8080.
 */
@Configuration
public class MobileClienteConfig {

    /**
     * Builder integrado con Spring Cloud LoadBalancer.
     *
     * Permite utilizar URLs basadas en Service ID,
     * por ejemplo:
     *
     * http://bank-backend
     */
    @Bean
    @LoadBalanced
    public WebClient.Builder loadBalancedWebClientBuilder() {
        return WebClient.builder();
    }

    /**
     * Cliente HTTP utilizado por BankBackendClient.
     *
     * La URL base proviene de Config Server mediante
     * la propiedad backend.base-url.
     */
    @Bean
    public WebClient webClient(
            @LoadBalanced WebClient.Builder loadBalancedWebClientBuilder,
            @Value("${backend.base-url}") String backendBaseUrl) {

        return loadBalancedWebClientBuilder
                .clone()
                .baseUrl(backendBaseUrl)
                .build();
    }
}