package cl.duoc.bancoxyz.bffmobile.service;

import cl.duoc.bancoxyz.bffmobile.dto.MobileCuentaResumen;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.List;
import java.util.Map;

@Service
public class MobileCuentaService {

    private final WebClient webClient;

    public MobileCuentaService(WebClient webClient) {
        this.webClient = webClient;
    }

    public List<MobileCuentaResumen> obtenerCuentas() {

        List<Map<String, Object>> cuentas = webClient
                .get()
                .uri("/api/cuentas")
                .retrieve()
                .bodyToMono(List.class)
                .block();

        return cuentas.stream()
                .map(cuenta -> new MobileCuentaResumen(
                        ((Number) cuenta.get("cuentaId")).longValue(),
                        (String) cuenta.get("nombre"),
                        (String) cuenta.get("tipo"),
                        (String) cuenta.get("estado"),
                        cuenta.get("saldoFinal")
                ))
                .toList();
    }

    public MobileCuentaResumen obtenerResumen(Long id) {

        Map<String, Object> cuenta = webClient
                .get()
                .uri("/api/cuentas/{id}", id)
                .retrieve()
                .bodyToMono(Map.class)
                .block();

        return new MobileCuentaResumen(
                ((Number) cuenta.get("cuentaId")).longValue(),
                (String) cuenta.get("nombre"),
                (String) cuenta.get("tipo"),
                (String) cuenta.get("estado"),
                cuenta.get("saldoFinal")
        );
    }
}