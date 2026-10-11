package cl.duoc.bancoxyz.cuentas.controller;
import cl.duoc.bancoxyz.cuentas.entity.CuentaInteres;
import cl.duoc.bancoxyz.cuentas.service.CuentasConsultaService;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
/** Contratos GET iguales a bank-backend, publicados en servicio distinto. */
@RestController
@RequestMapping("/api/cuentas")
public class CuentasController {
 private final CuentasConsultaService service;
 public CuentasController(CuentasConsultaService service) {this.service=service;}
 @GetMapping
 public ResponseEntity<List<CuentaInteres>> obtenerTodas() {return ResponseEntity.ok(service.obtenerTodas());}
 @GetMapping("/{id}")
 public ResponseEntity<CuentaInteres> obtenerPorId(@PathVariable Long id) {
  return service.obtenerPorId(id).map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
 }
}
