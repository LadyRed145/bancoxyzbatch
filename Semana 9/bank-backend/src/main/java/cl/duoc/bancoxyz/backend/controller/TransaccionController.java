package cl.duoc.bancoxyz.backend.controller;

import cl.duoc.bancoxyz.backend.entity.TransaccionProcesada;
import cl.duoc.bancoxyz.backend.service.TransaccionProcesadaService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/transacciones")
public class TransaccionController {

    private final TransaccionProcesadaService service;

    public TransaccionController(TransaccionProcesadaService service) {
        this.service = service;
    }

    @GetMapping
    public ResponseEntity<List<TransaccionProcesada>> obtenerTodas() {
        return ResponseEntity.ok(service.obtenerTodas());
    }

    @GetMapping("/{id}")
    public ResponseEntity<TransaccionProcesada> obtenerPorId(
            @PathVariable Long id) {

        return service.obtenerPorId(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}