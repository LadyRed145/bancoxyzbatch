package cl.duoc.bancoxyz.bffweb.service;

import cl.duoc.bancoxyz.bffweb.client.BankBackendClient;
import cl.duoc.bancoxyz.bffweb.dto.WebCuentaDetalle;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Mono;
import tools.jackson.databind.JsonNode;

@Service
public class WebCuentaService {

    private final BankBackendClient bankBackendClient;

    public WebCuentaService(BankBackendClient bankBackendClient) {
        this.bankBackendClient = bankBackendClient;
    }

    public JsonNode obtenerCuentas() {
        return bankBackendClient.obtenerCuentas().block();
    }

    public JsonNode obtenerCuenta(Long id) {
        return bankBackendClient.obtenerCuenta(id).block();
    }

    public WebCuentaDetalle obtenerDetalleCuenta(Long id) {
        // En Web coordino ambas consultas en paralelo porque este canal necesita una vista más completa.
        return Mono.zip(
                bankBackendClient.obtenerCuenta(id),
                bankBackendClient.obtenerEstadosCuenta(id),
                WebCuentaDetalle::new
        ).block();
    }
}
