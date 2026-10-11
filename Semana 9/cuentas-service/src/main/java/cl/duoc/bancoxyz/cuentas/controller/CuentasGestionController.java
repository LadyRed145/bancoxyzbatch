package cl.duoc.bancoxyz.cuentas.controller;
import cl.duoc.bancoxyz.cuentas.dto.*;
import cl.duoc.bancoxyz.cuentas.service.CuentasGestionService;
import jakarta.validation.Valid;
import java.net.URI;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
/** API de gestion independiente de los endpoints legacy /api/cuentas. */
@RestController
@RequestMapping("/api/cuentas/gestion")
public class CuentasGestionController {
 private final CuentasGestionService service;
 public CuentasGestionController(CuentasGestionService service){this.service=service;}
 @GetMapping public List<CuentaGestionResponse> listar(){return service.listar();}
 @GetMapping("/{id}") public CuentaGestionResponse obtener(@PathVariable long id){return service.obtener(id);}
 @PostMapping public ResponseEntity<CuentaGestionResponse> abrir(@Valid @RequestBody AperturaCuentaRequest req){
  var c=service.abrir(req);return ResponseEntity.created(URI.create("/api/cuentas/gestion/"+c.id())).body(c);
 }
 @PutMapping("/{id}") public CuentaGestionResponse actualizar(@PathVariable long id,@Valid @RequestBody MantenimientoCuentaRequest req){return service.actualizar(id,req);}
 @PostMapping("/{id}/cierre") public CuentaGestionResponse cerrar(@PathVariable long id){return service.cerrar(id);}
}
