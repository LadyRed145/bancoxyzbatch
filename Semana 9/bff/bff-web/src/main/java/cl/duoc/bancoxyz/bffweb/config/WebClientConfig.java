package cl.duoc.bancoxyz.bffweb.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

/**
 * Configuración del cliente HTTP utilizado por BFF Web.
 *
 * El WebClient.Builder está integrado con Spring Cloud LoadBalancer,
 * por lo que backend.base-url puede utilizar el nombre lógico
 * registrado en Eureka en lugar de una dirección física.
 */
@Configuration
public class WebClientConfig {

    /**
     * Builder integrado con Service Discovery.
     *
     * Permite resolver URLs como:
     * http://bank-backend
     */
    @Bean
    @LoadBalanced
    public WebClient.Builder loadBalancedWebClientBuilder() {
        return WebClient.builder();
    }

    /**
     * WebClient utilizado por BankBackendClient.
     *
     * La URL base se obtiene desde Config Server.
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