package cl.duoc.bancoxyz.bffatm.controller;

import cl.duoc.bancoxyz.bffatm.dto.AtmCuentaSaldo;
import cl.duoc.bancoxyz.bffatm.service.AtmCuentaService;
import cl.duoc.bancoxyz.bffatm.dto.AtmRetiroRequest;
import org.springframework.web.bind.annotation.*;


@RestController
@RequestMapping("/api/atm/cuentas")
public class AtmCuentaController {

    private final AtmCuentaService atmCuentaService;

    public AtmCuentaController(AtmCuentaService atmCuentaService) {
        this.atmCuentaService = atmCuentaService;
    }

    @GetMapping("/{id}/saldo")
    public AtmCuentaSaldo consultarSaldo(@PathVariable Long id) {
        return atmCuentaService.consultarSaldo(id);
    }
    @PostMapping("/{id}/retiro")
    public Object retirar(
            @PathVariable Long id,
            @RequestBody AtmRetiroRequest request) {

        return atmCuentaService.retirar(id, request.getMonto());
    }
}