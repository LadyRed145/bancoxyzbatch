package cl.duoc.bancoxyz.bffmobile.client;

import cl.duoc.bancoxyz.shared.resilience.BackendResilienceSupport;
import io.github.resilience4j.ratelimiter.RateLimiterRegistry;
import io.github.resilience4j.retry.RetryRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.client.circuitbreaker.ReactiveCircuitBreakerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;
import java.util.List;
import java.util.Map;
import org.springframework.core.ParameterizedTypeReference;

import java.time.Duration;

/**
 * Cliente HTTP del canal MOBILE.
 * Los endpoints y DTO siguen siendo locales al BFF; resiliencia compartida.
 * El POST de retiro de ATM permanece sin reintentos automáticos.
 */
@Component
public class BankBackendClient {

    private static final String RESILIENCE_ID = "bankbackend";

    private final WebClient webClient;
    private final BackendResilienceSupport resilience;

    public BankBackendClient(
            WebClient webClient,
            ReactiveCircuitBreakerFactory<?, ?> circuitBreakerFactory,
            RetryRegistry retryRegistry,
            RateLimiterRegistry rateLimiterRegistry,
            @Value("${backend.timeout:3s}") Duration backendTimeout) {
        this.webClient = webClient;
        this.resilience = new BackendResilienceSupport(
                backendTimeout,
                circuitBreakerFactory.create(RESILIENCE_ID),
                retryRegistry.retry(RESILIENCE_ID),
                rateLimiterRegistry.rateLimiter(RESILIENCE_ID));
    }

    public Mono<List<Map<String, Object>>> obtenerCuentas() {
        return resilience.protegerLectura(
                webClient.get()
                        .uri("http://cuentas-service/api/cuentas")
                        .headers(headers -> { var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication(); if (auth instanceof org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken jwt) headers.setBearerAuth(jwt.getToken().getTokenValue()); })
                        .retrieve()
                        .bodyToMono(new ParameterizedTypeReference<List<Map<String, Object>>>() {
                        }),
                "obtener el listado de cuentas"
        );
    }

    public Mono<Map<String, Object>> obtenerCuenta(Long id) {
        return resilience.protegerLectura(
                webClient.get()
                        .uri("http://cuentas-service/api/cuentas/{id}", id)
                        .headers(headers -> { var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication(); if (auth instanceof org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken jwt) headers.setBearerAuth(jwt.getToken().getTokenValue()); })
                        .retrieve()
                        .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {
                        }),
                "obtener la cuenta " + id
        );
    }
}
