package cl.duoc.bancoxyz.bffweb.controller;

import cl.duoc.bancoxyz.bffweb.dto.WebCuentaDetalle;
import cl.duoc.bancoxyz.bffweb.service.WebCuentaService;
import tools.jackson.databind.JsonNode;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/web/cuentas")
public class WebCuentaController {

    private final WebCuentaService webCuentaService;

    public WebCuentaController(WebCuentaService webCuentaService) {
        this.webCuentaService = webCuentaService;
    }

    @GetMapping
    public JsonNode obtenerCuentas() {
        return webCuentaService.obtenerCuentas();
    }

    @GetMapping("/{id}")
    public JsonNode obtenerCuenta(@PathVariable Long id) {
        return webCuentaService.obtenerCuenta(id);
    }

    @GetMapping("/{id}/detalle")
    public WebCuentaDetalle obtenerDetalleCuenta(@PathVariable Long id) {
        return webCuentaService.obtenerDetalleCuenta(id);
    }
}