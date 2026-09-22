package cl.duoc.bancoxyz.bffatm.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

/**
 * Configuración del cliente HTTP utilizado por BFF ATM.
 *
 * Spring Cloud LoadBalancer permite resolver dinámicamente
 * bank-backend mediante Eureka Service Discovery.
 */
@Configuration
public class AtmClienteConfig {

    /**
     * Builder integrado con Spring Cloud LoadBalancer.
     *
     * Permite utilizar el nombre lógico registrado
     * en Eureka:
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