package cl.duoc.bancoxyz.bffweb.controller;

import cl.duoc.bancoxyz.bffweb.service.WebCuentaService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/web/cuentas")
public class WebCuentaController {

    private final WebCuentaService webCuentaService;

    public WebCuentaController(WebCuentaService webCuentaService) {
        this.webCuentaService = webCuentaService;
    }

    @GetMapping
    public Object obtenerCuentas() {
        return webCuentaService.obtenerCuentas();
    }

    @GetMapping("/{id}")
    public Object obtenerCuenta(@PathVariable Long id) {
        return webCuentaService.obtenerCuenta(id);
    }

    @GetMapping("/{id}/detalle")
    public Object obtenerDetalleCuenta(@PathVariable Long id) {
        return webCuentaService.obtenerDetalleCuenta(id);
    }
}

