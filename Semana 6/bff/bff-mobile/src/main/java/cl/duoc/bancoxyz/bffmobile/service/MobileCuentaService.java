package cl.duoc.bancoxyz.bffmobile.service;

import cl.duoc.bancoxyz.bffmobile.client.BankBackendClient;
import cl.duoc.bancoxyz.bffmobile.dto.MobileCuentaResumen;
import cl.duoc.bancoxyz.bffmobile.mapper.MobileCuentaMapper;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class MobileCuentaService {

    private final BankBackendClient bankBackendClient;
    private final MobileCuentaMapper mobileCuentaMapper;

    public MobileCuentaService(
            BankBackendClient bankBackendClient,
            MobileCuentaMapper mobileCuentaMapper) {
        this.bankBackendClient = bankBackendClient;
        this.mobileCuentaMapper = mobileCuentaMapper;
    }

    public List<MobileCuentaResumen> obtenerCuentas() {
        List<Map<String, Object>> cuentas = bankBackendClient.obtenerCuentas().block();

        if (cuentas == null) {
            return List.of();
        }

        return cuentas.stream()
                .map(mobileCuentaMapper::aResumen)
                .toList();
    }

    public MobileCuentaResumen obtenerResumen(Long id) {
        Map<String, Object> cuenta = bankBackendClient.obtenerCuenta(id).block();

        if (cuenta == null) {
            throw new IllegalStateException(
                    "El backend no devolvió información para la cuenta " + id
            );
        }

        return mobileCuentaMapper.aResumen(cuenta);
    }
}
