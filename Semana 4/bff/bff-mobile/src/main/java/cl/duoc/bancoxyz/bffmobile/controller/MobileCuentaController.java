package cl.duoc.bancoxyz.bffmobile.controller;

import cl.duoc.bancoxyz.bffmobile.dto.MobileCuentaResumen;
import cl.duoc.bancoxyz.bffmobile.service.MobileCuentaService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/mobile/cuentas")
public class MobileCuentaController {

    private final MobileCuentaService mobileCuentaService;

    public MobileCuentaController(MobileCuentaService mobileCuentaService) {
        this.mobileCuentaService = mobileCuentaService;
    }

    @GetMapping
    public Object obtenerCuentas() {
        return mobileCuentaService.obtenerCuentas();
    }

    @GetMapping("/{id}/resumen")
    public MobileCuentaResumen obtenerResumen(@PathVariable Long id) {
        return mobileCuentaService.obtenerResumen(id);
    }
}