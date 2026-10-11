package cl.duoc.bancoxyz.shared.resilience;

import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;
import io.github.resilience4j.ratelimiter.RateLimiter;
import io.github.resilience4j.ratelimiter.RateLimiterConfig;
import io.github.resilience4j.ratelimiter.RequestNotPermitted;
import io.github.resilience4j.reactor.circuitbreaker.operator.CircuitBreakerOperator;
import io.github.resilience4j.reactor.ratelimiter.operator.RateLimiterOperator;
import org.junit.jupiter.api.Test;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * Pruebas reales de los operadores Resilience4j, aisladas de HTTP, Kafka y PostgreSQL.
 * No sustituye la prueba de configuración Spring Cloud / Config Server desplegada.
 */
class BackendResilienceRealComponentsTest {

    @Test
    void circuitoRealAbreBloqueaYRecuperaEnHalfOpen() {
        CircuitBreakerConfig configuracion = CircuitBreakerConfig.custom()
                .slidingWindowType(CircuitBreakerConfig.SlidingWindowType.COUNT_BASED)
                .slidingWindowSize(5)
                .minimumNumberOfCalls(3)
                .failureRateThreshold(50.0f)
                .waitDurationInOpenState(Duration.ofSeconds(10))
                .automaticTransitionFromOpenToHalfOpenEnabled(false)
                .permittedNumberOfCallsInHalfOpenState(2)
                .recordExceptions(BackendNoDisponibleException.class, BackendTimeoutException.class)
                .build();

        CircuitBreaker circuito = CircuitBreaker.of("bankbackend-real-test", configuracion);
        AtomicInteger ejecuciones = new AtomicInteger();
        Mono<String> falla = Mono.defer(() -> {
            ejecuciones.incrementAndGet();
            return Mono.error(new BackendNoDisponibleException(
                    "consulta simulada", new IllegalStateException("sin conexión")));
        });

        for (int intento = 0; intento < 3; intento++) {
            assertThrows(BackendNoDisponibleException.class,
                    () -> falla.transformDeferred(CircuitBreakerOperator.of(circuito)).block());
        }
        assertEquals(CircuitBreaker.State.OPEN, circuito.getState());
        assertThrows(CallNotPermittedException.class,
                () -> falla.transformDeferred(CircuitBreakerOperator.of(circuito)).block());
        assertEquals(3, ejecuciones.get(), "OPEN no debe invocar la operación remota");

        // No esperamos 10 segundos: forzamos HALF_OPEN solo dentro del test.
        circuito.transitionToHalfOpenState();
        for (int prueba = 0; prueba < 2; prueba++) {
            assertEquals("OK", Mono.just("OK")
                    .transformDeferred(CircuitBreakerOperator.of(circuito)).block());
        }
        assertEquals(CircuitBreaker.State.CLOSED, circuito.getState());
    }

    @Test
    void limitadorRealNiegaTerceraSolicitudSinConsumirOperacion() {
        RateLimiter limiter = RateLimiter.of("limitador-real-test", RateLimiterConfig.custom()
                .limitForPeriod(2)
                .limitRefreshPeriod(Duration.ofSeconds(30))
                .timeoutDuration(Duration.ZERO)
                .build());

        AtomicInteger ejecuciones = new AtomicInteger();
        Mono<String> operacion = Mono.fromSupplier(() -> {
            ejecuciones.incrementAndGet();
            return "OK";
        });
        for (int i = 0; i < 2; i++) {
            assertEquals("OK", operacion.transformDeferred(RateLimiterOperator.of(limiter)).block());
        }
        assertThrows(RequestNotPermitted.class,
                () -> operacion.transformDeferred(RateLimiterOperator.of(limiter)).block());
        assertEquals(2, ejecuciones.get(), "La solicitud bloqueada nunca llega al backend");
    }
}
