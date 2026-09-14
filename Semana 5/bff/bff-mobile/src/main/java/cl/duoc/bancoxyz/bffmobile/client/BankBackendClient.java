package cl.duoc.bancoxyz.bffmobile.client;

import cl.duoc.bancoxyz.bffmobile.exception.BackendNoDisponibleException;
import cl.duoc.bancoxyz.bffmobile.exception.BackendTimeoutException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientRequestException;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.List;
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

    public Mono<List<Map<String, Object>>> obtenerCuentas() {
        return proteger(
                webClient.get()
                        .uri("/api/cuentas")
                        .retrieve()
                        .bodyToMono(new ParameterizedTypeReference<List<Map<String, Object>>>() {}),
                "obtener el listado de cuentas"
        );
    }

    public Mono<Map<String, Object>> obtenerCuenta(Long id) {
        return proteger(
                webClient.get()
                        .uri("/api/cuentas/{id}", id)
                        .retrieve()
                        .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {}),
                "obtener la cuenta " + id
        );
    }

    private <T> Mono<T> proteger(Mono<T> operacion, String descripcion) {
        // Mantengo timeout y fallos de conexión dentro de la capa client para que el Service solo coordine datos.
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
