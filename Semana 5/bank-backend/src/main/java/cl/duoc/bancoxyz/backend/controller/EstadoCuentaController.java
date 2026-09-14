package cl.duoc.bancoxyz.backend.controller;

import cl.duoc.bancoxyz.backend.entity.EstadoCuentaAnual;
import cl.duoc.bancoxyz.backend.service.EstadoCuentaAnualService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/estados-cuenta")
public class EstadoCuentaController {

    private final EstadoCuentaAnualService service;

    public EstadoCuentaController(EstadoCuentaAnualService service) {
        this.service = service;
    }

    @GetMapping
    public ResponseEntity<List<EstadoCuentaAnual>> obtenerTodos() {
        return ResponseEntity.ok(service.obtenerTodos());
    }

    @GetMapping("/cuenta/{cuentaId}")
    public ResponseEntity<List<EstadoCuentaAnual>> obtenerPorCuenta(
            @PathVariable Long cuentaId) {

        return ResponseEntity.ok(service.obtenerPorCuenta(cuentaId));
    }
}