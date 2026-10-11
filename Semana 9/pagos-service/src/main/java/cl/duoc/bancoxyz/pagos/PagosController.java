package cl.duoc.bancoxyz.pagos;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.UUID;

/** API de operaciones monetarias sobre cuentas_gestion; no modifica datos Batch. */
@RestController
@RequestMapping("/api/pagos")
public class PagosController {
    private final PagosService service;

    public PagosController(PagosService service) {
        this.service = service;
    }

    public record Solicitud(
            @NotNull Tipo tipo,
            @Positive long origen,
            @Positive long destino,
            @NotNull @DecimalMin("0.01") @Digits(integer = 16, fraction = 2) BigDecimal monto) {}

    public enum Tipo { PAGO, TRANSFERENCIA, DEPOSITO }

    public record Estado(UUID id, Tipo tipo, BigDecimal monto, String estado) {}
    public record SaldoCuenta(long cuentaId, BigDecimal saldoActual) {}

    /** Procesamiento sincrónico y atómico: devuelve APLICADO solo tras commit exitoso. */
    @PostMapping("/solicitudes")
    public Estado registrar(@RequestHeader("Idempotency-Key") UUID clave,
                           @Valid @RequestBody Solicitud solicitud) {
        return service.procesar(clave, solicitud);
    }

    @GetMapping("/solicitudes/{id}")
    public Estado consultar(@PathVariable UUID id) {
        return service.consultar(id);
    }

    @GetMapping("/cuentas/{id}/saldo")
    public ResponseEntity<SaldoCuenta> saldo(@PathVariable long id) {
        return ResponseEntity.ok(service.saldo(id));
    }
}
