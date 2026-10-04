package cl.duoc.bancoxyz.bffatm.service;

import cl.duoc.bancoxyz.bffatm.client.BankBackendClient;
import cl.duoc.bancoxyz.bffatm.dto.AtmCuentaSaldo;
import cl.duoc.bancoxyz.bffatm.dto.AtmRetiroRequest;
import cl.duoc.bancoxyz.bffatm.dto.AtmRetiroResponse;
import cl.duoc.bancoxyz.bffatm.mapper.AtmCuentaMapper;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.Map;

@Service
public class AtmCuentaService {

    private final BankBackendClient bankBackendClient;
    private final AtmCuentaMapper atmCuentaMapper;

    public AtmCuentaService(
            BankBackendClient bankBackendClient,
            AtmCuentaMapper atmCuentaMapper) {
        this.bankBackendClient = bankBackendClient;
        this.atmCuentaMapper = atmCuentaMapper;
    }

    public AtmCuentaSaldo consultarSaldo(Long id) {
        Map<String, Object> cuenta = bankBackendClient.obtenerCuenta(id).block();

        if (cuenta == null) {
            throw new IllegalStateException(
                    "El backend no devolvió información para la cuenta " + id
            );
        }

        return atmCuentaMapper.aSaldo(cuenta);
    }

    public AtmRetiroResponse retirar(Long id, BigDecimal monto) {
        AtmRetiroRequest request = new AtmRetiroRequest(monto);
        Map<String, Object> cuentaActualizada = bankBackendClient.retirar(id, request).block();

        if (cuentaActualizada == null) {
            throw new IllegalStateException(
                    "El backend no devolvió información luego del retiro de la cuenta " + id
            );
        }

        return atmCuentaMapper.aRetiro(cuentaActualizada, monto);
    }
}
