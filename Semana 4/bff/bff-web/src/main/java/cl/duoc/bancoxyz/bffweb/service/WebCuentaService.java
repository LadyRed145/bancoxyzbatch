package cl.duoc.bancoxyz.bffweb.service;

import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import cl.duoc.bancoxyz.bffweb.dto.WebCuentaDetalle;

@Service
public class WebCuentaService {

    private final WebClient webClient;

    public WebCuentaService(WebClient webClient) {
        this.webClient = webClient;
    }

    public Object obtenerCuentas() {
        return webClient
                .get()
                .uri("/api/cuentas")
                .retrieve()
                .bodyToMono(Object.class)
                .block();
    }

    public Object obtenerCuenta(Long id) {
        return webClient
                .get()
                .uri("/api/cuentas/{id}", id)
                .retrieve()
                .bodyToMono(Object.class)
                .block();
    }

    public WebCuentaDetalle obtenerDetalleCuenta(Long id) {

        Object cuenta = webClient
                .get()
                .uri("/api/cuentas/{id}", id)
                .retrieve()
                .bodyToMono(Object.class)
                .block();

        Object estadosCuenta = webClient
                .get()
                .uri("/api/estados-cuenta/cuenta/{cuentaId}", id)
                .retrieve()
                .bodyToMono(Object.class)
                .block();

        return new WebCuentaDetalle(cuenta, estadosCuenta);
    }
}



