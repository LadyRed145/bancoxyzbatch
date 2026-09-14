package cl.duoc.bancoxyz.bffweb.client;

import cl.duoc.bancoxyz.bffweb.exception.BackendNoDisponibleException;
import cl.duoc.bancoxyz.bffweb.exception.BackendTimeoutException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientRequestException;
import reactor.core.publisher.Mono;
import tools.jackson.databind.JsonNode;

import java.time.Duration;
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

    public Mono<JsonNode> obtenerCuentas() {
        return proteger(
                webClient.get()
                        .uri("/api/cuentas")
                        .retrieve()
                        .bodyToMono(JsonNode.class),
                "obtener el listado de cuentas"
        );
    }

    public Mono<JsonNode> obtenerCuenta(Long id) {
        return proteger(
                webClient.get()
                        .uri("/api/cuentas/{id}", id)
                        .retrieve()
                        .bodyToMono(JsonNode.class),
                "obtener la cuenta " + id
        );
    }

    public Mono<JsonNode> obtenerEstadosCuenta(Long id) {
        return proteger(
                webClient.get()
                        .uri("/api/estados-cuenta/cuenta/{cuentaId}", id)
                        .retrieve()
                        .bodyToMono(JsonNode.class),
                "obtener los estados de cuenta de " + id
        );
    }

    private <T> Mono<T> proteger(Mono<T> operacion, String descripcion) {
        // Centralizo aquí la resiliencia del cliente para no mezclar detalles HTTP con la lógica del servicio.
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
