package cl.duoc.bancoxyz.bffatm.client;

import cl.duoc.bancoxyz.bffatm.dto.AtmRetiroRequest;
import cl.duoc.bancoxyz.bffatm.exception.BackendNoDisponibleException;
import cl.duoc.bancoxyz.bffatm.exception.BackendTimeoutException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientRequestException;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.TimeoutException;

@Component
public class BankBackendClient {

    private final WebClient webClient;
    private final Duration backendTimeout;

    public BankBackendClient(
            WebClient webClient,
            @Value("${backend.timeout:3s}") Duration backendTimeout) {
        this.webClient = webClient;
        this.backendTimeout = backendTimeout;
    }

    public Mono<Map<String, Object>> obtenerCuenta(Long id) {
        return proteger(
                webClient.get()
                        .uri("/api/cuentas/{id}", id)
                        .retrieve()
                        .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {}),
                "consultar la cuenta " + id
        );
    }

    public Mono<Map<String, Object>> retirar(Long id, AtmRetiroRequest request) {
        return proteger(
                webClient.post()
                        .uri("/api/cuentas/{id}/retiro", id)
                        .bodyValue(request)
                        .retrieve()
                        .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {}),
                "procesar el retiro de la cuenta " + id
        );
    }

    private <T> Mono<T> proteger(Mono<T> operacion, String descripcion) {
        // El cajero no puede quedarse esperando indefinidamente: corto la dependencia y traduzco el fallo después.
        return operacion
                .timeout(backendTimeout)
                .onErrorMap(
                        TimeoutException.class,
                        exception -> new BackendTimeoutException(descripcion, exception)
                )
                .onErrorMap(
                        WebClientRequestException.class,
                        exception -> new BackendNoDisponibleException(descripcion, exception)
                );
    }
}
