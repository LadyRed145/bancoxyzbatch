package cl.duoc.bancoxyz.backend.controller;

import cl.duoc.bancoxyz.backend.entity.ResumenTransaccionesDiarias;
import cl.duoc.bancoxyz.backend.service.ResumenTransaccionesService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/resumenes")
public class ResumenTransaccionesController {

    private final ResumenTransaccionesService service;

    public ResumenTransaccionesController(
            ResumenTransaccionesService service) {
        this.service = service;
    }

    @GetMapping
    public ResponseEntity<List<ResumenTransaccionesDiarias>> obtenerTodos() {
        return ResponseEntity.ok(service.obtenerTodos());
    }

    @GetMapping("/{fecha}")
    public ResponseEntity<ResumenTransaccionesDiarias> obtenerPorFecha(
            @PathVariable LocalDate fecha) {

        ResumenTransaccionesDiarias resumen =
                service.obtenerPorFecha(fecha);

        if (resumen == null) {
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.ok(resumen);
    }
}