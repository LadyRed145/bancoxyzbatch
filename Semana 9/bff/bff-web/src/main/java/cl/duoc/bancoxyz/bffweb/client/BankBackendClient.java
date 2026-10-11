package cl.duoc.bancoxyz.bffweb.client;

import cl.duoc.bancoxyz.shared.resilience.BackendResilienceSupport;
import io.github.resilience4j.ratelimiter.RateLimiterRegistry;
import io.github.resilience4j.retry.RetryRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.client.circuitbreaker.ReactiveCircuitBreakerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;
import tools.jackson.databind.JsonNode;

import java.time.Duration;

/**
 * Cliente HTTP del canal WEB.
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

    public Mono<JsonNode> obtenerCuentas() {
        return resilience.protegerLectura(
                webClient.get()
                        .uri("http://cuentas-service/api/cuentas")
                        .headers(headers -> { var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication(); if (auth instanceof org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken jwt) headers.setBearerAuth(jwt.getToken().getTokenValue()); })
                        .retrieve()
                        .bodyToMono(JsonNode.class),
                "obtener el listado de cuentas"
        );
    }

    public Mono<JsonNode> obtenerCuenta(Long id) {
        return resilience.protegerLectura(
                webClient.get()
                        .uri("http://cuentas-service/api/cuentas/{id}", id)
                        .headers(headers -> { var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication(); if (auth instanceof org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken jwt) headers.setBearerAuth(jwt.getToken().getTokenValue()); })
                        .retrieve()
                        .bodyToMono(JsonNode.class),
                "obtener la cuenta " + id
        );
    }

    public Mono<JsonNode> obtenerEstadosCuenta(Long id) {
        String jwtBackend = jwtParaBackend();
        return resilience.protegerLectura(
                webClient.get()
                        .uri("/api/estados-cuenta/cuenta/{cuentaId}", id)
                        .headers(headers -> headers.setBearerAuth(jwtBackend))
                        .retrieve()
                        .bodyToMono(JsonNode.class),
                "obtener los estados de cuenta de " + id
        );
    }

    /**
     * Recupera el JWT validado en el contexto de la solicitud HTTP.
     * Nunca registra el token en logs.
     */
    private String jwtParaBackend() {
        var autenticacion =
                org.springframework.security.core.context.SecurityContextHolder
                        .getContext().getAuthentication();

        if (autenticacion instanceof
                org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken jwt
                && autenticacion.isAuthenticated()) {
            return jwt.getToken().getTokenValue();
        }

        throw new org.springframework.security.authentication.InsufficientAuthenticationException(
                "JWT autenticado no disponible para backend");
    }

}
