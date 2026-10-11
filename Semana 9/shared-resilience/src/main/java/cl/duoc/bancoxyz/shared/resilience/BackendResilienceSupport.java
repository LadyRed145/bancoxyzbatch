package cl.duoc.bancoxyz.shared.resilience;

import io.github.resilience4j.ratelimiter.RateLimiter;
import io.github.resilience4j.reactor.ratelimiter.operator.RateLimiterOperator;
import io.github.resilience4j.reactor.retry.RetryOperator;
import io.github.resilience4j.retry.Retry;
import org.springframework.cloud.client.circuitbreaker.ReactiveCircuitBreaker;
import org.springframework.web.reactive.function.client.WebClientRequestException;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.Objects;
import java.util.concurrent.TimeoutException;

/**
 * Protección HTTP reutilizable por BFF Web, Mobile y ATM.
 *
 * El orden de operadores reproduce el comportamiento anterior:
 * timeout -> normalización -> Retry SOLO para lecturas -> Circuit Breaker
 * -> Rate Limiter exterior. Nunca reintentar operaciones financieras POST.
 * No es un @Component: cada BFF configura sus instancias por separado.
 */
public final class BackendResilienceSupport {

    private final Duration backendTimeout;
    private final ReactiveCircuitBreaker circuitBreaker;
    private final Retry retry;
    private final RateLimiter rateLimiter;

    public BackendResilienceSupport(
            Duration backendTimeout,
            ReactiveCircuitBreaker circuitBreaker,
            Retry retry,
            RateLimiter rateLimiter) {
        this.backendTimeout = Objects.requireNonNull(backendTimeout, "backendTimeout");
        this.circuitBreaker = Objects.requireNonNull(circuitBreaker, "circuitBreaker");
        this.retry = Objects.requireNonNull(retry, "retry");
        this.rateLimiter = Objects.requireNonNull(rateLimiter, "rateLimiter");
    }

    /** Consultas GET: preservan Retry configurado (max-attempts=3 en Config Server). */
    public <T> Mono<T> protegerLectura(Mono<T> operacion, String descripcion) {
        Mono<T> normalizada = normalizarErrores(operacion, descripcion);
        Mono<T> conRetry = normalizada.transformDeferred(RetryOperator.of(retry));
        return aplicarCircuitBreakerYRateLimit(conRetry, descripcion);
    }

    /** Operaciones no idempotentes (por ejemplo, retiro POST): sin Retry. */
    public <T> Mono<T> protegerSinRetry(Mono<T> operacion, String descripcion) {
        return aplicarCircuitBreakerYRateLimit(
                normalizarErrores(operacion, descripcion), descripcion);
    }

    private <T> Mono<T> normalizarErrores(Mono<T> operacion, String descripcion) {
        return operacion
                .timeout(backendTimeout)
                .onErrorMap(TimeoutException.class,
                        exception -> new BackendTimeoutException(descripcion, exception))
                .onErrorMap(WebClientRequestException.class,
                        exception -> new BackendNoDisponibleException(descripcion, exception))
                .onErrorMap(throwable -> throwable instanceof WebClientResponseException exception
                                && exception.getStatusCode().value() == 503,
                        exception -> new BackendNoDisponibleException(descripcion, exception));
    }

    private <T> Mono<T> aplicarCircuitBreakerYRateLimit(Mono<T> operacion, String descripcion) {
        Mono<T> conCircuitBreaker = circuitBreaker.run(operacion,
                throwable -> fallback(throwable, descripcion));
        // Exterior: las solicitudes rechazadas por Rate Limiter no llegan al CB.
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
