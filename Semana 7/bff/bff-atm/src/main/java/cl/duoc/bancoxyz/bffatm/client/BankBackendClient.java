package cl.duoc.bancoxyz.bffatm.client;

import cl.duoc.bancoxyz.bffatm.dto.AtmRetiroRequest;
import cl.duoc.bancoxyz.bffatm.exception.BackendNoDisponibleException;
import cl.duoc.bancoxyz.bffatm.exception.BackendTimeoutException;
import io.github.resilience4j.ratelimiter.RateLimiter;
import io.github.resilience4j.ratelimiter.RateLimiterRegistry;
import io.github.resilience4j.reactor.ratelimiter.operator.RateLimiterOperator;
import io.github.resilience4j.reactor.retry.RetryOperator;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.retry.RetryRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.client.circuitbreaker.ReactiveCircuitBreaker;
import org.springframework.cloud.client.circuitbreaker.ReactiveCircuitBreakerFactory;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientRequestException;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.TimeoutException;

/**
 * Cliente reactivo del canal ATM.
 *
 * Las consultas GET usan Retry de hasta 3 intentos. El retiro POST no se
 * reintenta porque no es idempotente y un reintento podría duplicar el débito.
 * Todas las operaciones conservan Rate Limiter, timeout, Circuit Breaker
 * y fallback.
 */
@Component
public class BankBackendClient {

    private static final String RESILIENCE_ID = "bankbackend";

    private final WebClient webClient;
    private final Duration backendTimeout;
    private final ReactiveCircuitBreaker circuitBreaker;
    private final Retry retry;
    private final RateLimiter rateLimiter;

    public BankBackendClient(
            WebClient webClient,
            ReactiveCircuitBreakerFactory<?, ?> circuitBreakerFactory,
            RetryRegistry retryRegistry,
            RateLimiterRegistry rateLimiterRegistry,
            @Value("${backend.timeout:3s}") Duration backendTimeout) {

        this.webClient = webClient;
        this.backendTimeout = backendTimeout;
        this.circuitBreaker = circuitBreakerFactory.create(RESILIENCE_ID);
        this.retry = retryRegistry.retry(RESILIENCE_ID);
        this.rateLimiter = rateLimiterRegistry.rateLimiter(RESILIENCE_ID);
    }

    public Mono<Map<String, Object>> obtenerCuenta(Long id) {
        return protegerLectura(
                webClient.get()
                        .uri("/api/cuentas/{id}", id)
                        .retrieve()
                        .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {
                        }),
                "consultar la cuenta " + id
        );
    }

    public Mono<Map<String, Object>> retirar(Long id, AtmRetiroRequest request) {
        return protegerSinRetry(
                webClient.post()
                        .uri("/api/cuentas/{id}/retiro", id)
                        .bodyValue(request)
                        .retrieve()
                        .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {
                        }),
                "procesar el retiro de la cuenta " + id
        );
    }

    private <T> Mono<T> protegerLectura(Mono<T> operacion, String descripcion) {
        Mono<T> normalizada = normalizarErrores(operacion, descripcion);
        Mono<T> conRetry = normalizada.transformDeferred(RetryOperator.of(retry));
        return aplicarCircuitBreakerYRateLimit(conRetry, descripcion);
    }

    private <T> Mono<T> protegerSinRetry(Mono<T> operacion, String descripcion) {
        return aplicarCircuitBreakerYRateLimit(
                normalizarErrores(operacion, descripcion),
                descripcion
        );
    }

    private <T> Mono<T> normalizarErrores(Mono<T> operacion, String descripcion) {
        return operacion
                .timeout(backendTimeout)
                .onErrorMap(
                        TimeoutException.class,
                        exception -> new BackendTimeoutException(descripcion, exception)
                )
                .onErrorMap(
                        WebClientRequestException.class,
                        exception -> new BackendNoDisponibleException(descripcion, exception)
                )
                .onErrorMap(
                        throwable -> throwable instanceof WebClientResponseException exception
                                && exception.getStatusCode().value() == 503,
                        exception -> new BackendNoDisponibleException(descripcion, exception)
                );
    }

    private <T> Mono<T> aplicarCircuitBreakerYRateLimit(Mono<T> operacion, String descripcion) {
        Mono<T> conCircuitBreaker = circuitBreaker.run(
                operacion,
                throwable -> fallback(throwable, descripcion)
        );

        return conCircuitBreaker.transformDeferred(RateLimiterOperator.of(rateLimiter));
    }

    private <T> Mono<T> fallback(Throwable throwable, String descripcion) {
        if (throwable instanceof BackendTimeoutException
                || throwable instanceof BackendNoDisponibleException
                || throwable instanceof WebClientResponseException) {
            return Mono.error(throwable);
        }

        return Mono.error(new BackendNoDisponibleException(descripcion, throwable));
    }
}
