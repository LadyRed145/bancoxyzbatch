package cl.duoc.bancoxyz.shared.resilience;

import io.github.resilience4j.ratelimiter.RateLimiter;
import io.github.resilience4j.ratelimiter.RateLimiterConfig;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.retry.RetryConfig;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.cloud.client.circuitbreaker.ReactiveCircuitBreaker;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Pruebas aisladas de regresión de la biblioteca compartida.
 * No utilizan base de datos, Kafka, servidores HTTP ni endpoints reales.
 *
 * Las operaciones financieras POST no pueden reintentarse silenciosamente.
 */
class BackendResilienceSupportTest {

    private BackendResilienceSupport support;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void configurar() {
        // Simular Circuit Breaker como paso directo; las pruebas se concentran
        // exclusivamente en la política Retry de cada tipo de operación.
        ReactiveCircuitBreaker circuitBreaker = mock(ReactiveCircuitBreaker.class);
        when(circuitBreaker.run(any(Mono.class), any()))
                .thenAnswer(invocation -> invocation.getArgument(0));

        Retry retry = Retry.of("prueba-lecturas", RetryConfig.custom()
                .maxAttempts(3)
                .waitDuration(Duration.ZERO)
                .retryExceptions(BackendNoDisponibleException.class)
                .build());

        RateLimiter rateLimiter = RateLimiter.of("prueba-limiter", RateLimiterConfig.custom()
                .limitForPeriod(100)
                .limitRefreshPeriod(Duration.ofSeconds(1))
                .timeoutDuration(Duration.ZERO)
                .build());

        support = new BackendResilienceSupport(
                Duration.ofSeconds(2), circuitBreaker, retry, rateLimiter);
    }

    @Test
    void lecturaGetDebeCompletarTrasTresIntentos() {
        AtomicInteger llamadas = new AtomicInteger();
        Mono<String> operacion = Mono.defer(() -> {
            if (llamadas.incrementAndGet() < 3) {
                return Mono.error(new BackendNoDisponibleException(
                        "consultar cuenta", new IllegalStateException("fallo simulado")));
            }
            return Mono.just("OK");
        });

        assertEquals("OK", support.protegerLectura(operacion, "consultar cuenta").block());
        assertEquals(3, llamadas.get(), "GET debe reintentar como máximo hasta 3 intentos");
    }

    @Test
    void retiroPostNoDebeReintentarCuandoFalla() {
        AtomicInteger llamadas = new AtomicInteger();
        Mono<String> operacion = Mono.defer(() -> {
            llamadas.incrementAndGet();
            return Mono.error(new BackendNoDisponibleException(
                    "procesar retiro", new IllegalStateException("fallo simulado")));
        });

        assertThrows(BackendNoDisponibleException.class,
                () -> support.protegerSinRetry(operacion, "procesar retiro").block());
        assertEquals(1, llamadas.get(), "POST retiro nunca debe repetir la operación");
    }
}
