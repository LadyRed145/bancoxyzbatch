package cl.duoc.bancoxyz.backend.controller;

import cl.duoc.bancoxyz.backend.entity.CuentaInteres;
import cl.duoc.bancoxyz.backend.service.CuentaInteresService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import cl.duoc.bancoxyz.backend.dto.RetiroRequest;
import jakarta.validation.Valid;

import java.util.List;

@RestController
@RequestMapping("/api/cuentas")
public class CuentaController {

    private final CuentaInteresService service;

    public CuentaController(CuentaInteresService service) {
        this.service = service;
    }

    @GetMapping
    public ResponseEntity<List<CuentaInteres>> obtenerTodas() {
        return ResponseEntity.ok(service.obtenerTodas());
    }

    @GetMapping("/{id}")
    public ResponseEntity<CuentaInteres> obtenerPorId(@PathVariable Long id) {
        return service.obtenerPorId(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/retiro")
    public CuentaInteres retirar(
            @PathVariable Long id,
            @Valid @RequestBody RetiroRequest request) {

        return service.retirar(id, request.getMonto());
    }
}