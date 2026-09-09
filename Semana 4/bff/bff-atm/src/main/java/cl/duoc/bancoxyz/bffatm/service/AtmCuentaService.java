package cl.duoc.bancoxyz.bffatm.service;

import cl.duoc.bancoxyz.bffatm.dto.AtmCuentaSaldo;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import cl.duoc.bancoxyz.bffatm.dto.AtmRetiroRequest;
import java.math.BigDecimal;
import java.util.Map;

@Service
public class AtmCuentaService {

    private final WebClient webClient;

    public AtmCuentaService(WebClient webClient) {
        this.webClient = webClient;
    }

    public AtmCuentaSaldo consultarSaldo(Long id) {

        Map<String, Object> cuenta = webClient
                .get()
                .uri("/api/cuentas/{id}", id)
                .retrieve()
                .bodyToMono(Map.class)
                .block();

        return new AtmCuentaSaldo(
                ((Number) cuenta.get("cuentaId")).longValue(),
                (String) cuenta.get("nombre"),
                cuenta.get("saldoFinal")
        );
    }
    public Object retirar(Long id, BigDecimal monto) {

        AtmRetiroRequest request = new AtmRetiroRequest(monto);

        return webClient
                .post()
                .uri("/api/cuentas/{id}/retiro", id)
                .bodyValue(request)
                .retrieve()
                .bodyToMono(Object.class)
                .block();
    }
}