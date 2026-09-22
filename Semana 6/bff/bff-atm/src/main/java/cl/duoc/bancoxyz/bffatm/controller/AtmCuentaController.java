package cl.duoc.bancoxyz.bffatm.controller;

import cl.duoc.bancoxyz.bffatm.dto.AtmCuentaSaldo;
import cl.duoc.bancoxyz.bffatm.dto.AtmRetiroRequest;
import cl.duoc.bancoxyz.bffatm.dto.AtmRetiroResponse;
import cl.duoc.bancoxyz.bffatm.service.AtmCuentaService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/atm/cuentas/{id}")
public class AtmCuentaController {

    private final AtmCuentaService atmCuentaService;

    public AtmCuentaController(AtmCuentaService atmCuentaService) {
        this.atmCuentaService = atmCuentaService;
    }

    @GetMapping("/saldo")
    public AtmCuentaSaldo consultarSaldo(@PathVariable Long id) {
        return atmCuentaService.consultarSaldo(id);
    }

    @PostMapping("/retiro")
    public AtmRetiroResponse retirar(
            @PathVariable Long id,
            @Valid @RequestBody AtmRetiroRequest request) {

        // El controlador solo valida el contrato HTTP; la regla financiera sigue viviendo en el backend central.
        return atmCuentaService.retirar(id, request.monto());
    }
}
