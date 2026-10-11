package cl.duoc.bancoxyz.pagos;

import cl.duoc.bancoxyz.pagos.PagosController.Estado;
import cl.duoc.bancoxyz.pagos.PagosController.SaldoCuenta;
import cl.duoc.bancoxyz.pagos.PagosController.Solicitud;
import cl.duoc.bancoxyz.pagos.PagosController.Tipo;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Libro mayor de laboratorio para cuentas_gestion.
 * No altera cuentas_intereses: esa tabla es un resultado reejecutable del Batch.
 * Todos los movimientos de una solicitud comparten UNA transacción PostgreSQL.
 */
@Service
public class PagosService {
    private final JdbcTemplate jdbc;

    public PagosService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional
    public Estado procesar(UUID clave, Solicitud s) {
        if (clave == null || s == null || s.tipo() == null || s.monto() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Solicitud incompleta");
        }
        if (s.origen() <= 0 || s.destino() <= 0 || s.origen() == s.destino()
                || s.monto().signum() <= 0 || s.monto().scale() > 2
                || s.monto().precision() - s.monto().scale() > 16) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cuenta o monto inválido");
        }

        // ON CONFLICT espera el commit de otra transacción con la misma clave.
        // Después, SELECT FOR UPDATE evita respuestas inconsistentes/concurrentes.
        int creada = jdbc.update("""
                INSERT INTO pagos_solicitudes(id,tipo,origen,destino,monto,estado)
                VALUES (?,?,?,?,?,'PENDIENTE') ON CONFLICT (id) DO NOTHING
                """, clave, s.tipo().name(), s.origen(), s.destino(), s.monto());

        List<Map<String, Object>> filas = jdbc.queryForList("""
                SELECT tipo,origen,destino,monto,estado
                FROM pagos_solicitudes WHERE id=? FOR UPDATE
                """, clave);
        if (filas.size() != 1) throw new IllegalStateException("No se pudo bloquear la solicitud");
        Map<String, Object> original = filas.get(0);
        BigDecimal montoGuardado = (BigDecimal) original.get("monto");
        if (!s.tipo().name().equals(original.get("tipo"))
                || ((Number) original.get("origen")).longValue() != s.origen()
                || ((Number) original.get("destino")).longValue() != s.destino()
                || montoGuardado.compareTo(s.monto()) != 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Idempotency-Key reutilizada con datos distintos");
        }
        if (creada == 0) {
            if ("APLICADO".equals(original.get("estado"))) {
                return new Estado(clave, s.tipo(), montoGuardado, "APLICADO");
            }
            // Solicitudes históricas PENDIENTE nunca se debitan automáticamente.
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Solicitud histórica no aplicada; usar una clave nueva tras verificarla");
        }

        boolean deposito = s.tipo() == Tipo.DEPOSITO;
        List<Long> cuentas = new ArrayList<>();
        if (!deposito) cuentas.add(s.origen());
        cuentas.add(s.destino());
        Collections.sort(cuentas); // Bloqueos consistentes: evita interbloqueos A->B / B->A.
        for (long cuentaId : cuentas) bloquearEInicializar(cuentaId);

        if (!deposito) {
            int debitadas = jdbc.update("""
                    UPDATE pagos_saldos SET saldo_actual=saldo_actual-?, actualizado_en=NOW()
                    WHERE cuenta_id=? AND saldo_actual>=?
                    """, s.monto(), s.origen(), s.monto());
            if (debitadas != 1) {
                // Rollback automático: tampoco se conserva la solicitud ni un abono parcial.
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Saldo insuficiente");
            }
            registrarMovimiento(clave, s.origen(), "DEBITO", s.monto());
        }
        int abonadas = jdbc.update("""
                UPDATE pagos_saldos SET saldo_actual=saldo_actual+?, actualizado_en=NOW()
                WHERE cuenta_id=?
                """, s.monto(), s.destino());
        if (abonadas != 1) throw new IllegalStateException("No se pudo acreditar la cuenta");
        registrarMovimiento(clave, s.destino(), "CREDITO", s.monto());

        int actualizadas = jdbc.update(
                "UPDATE pagos_solicitudes SET estado='APLICADO' WHERE id=? AND estado='PENDIENTE'", clave);
        if (actualizadas != 1) throw new IllegalStateException("Estado de liquidación inesperado");
        return new Estado(clave, s.tipo(), s.monto(), "APLICADO");
    }

    private void bloquearEInicializar(long id) {
        // Primero se bloquea cuentas_gestion: serializa la apertura del saldo inicial.
        List<Map<String, Object>> activas = jdbc.queryForList("""
                SELECT id,estado FROM cuentas_gestion WHERE id=? FOR UPDATE
                """, id);
        if (activas.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                "Cuenta de gestión no encontrada: " + id);
        if (!"ACTIVA".equals(activas.get(0).get("estado"))) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Cuenta de gestión cerrada: " + id);
        }
        jdbc.update("""
                INSERT INTO pagos_saldos(cuenta_id,saldo_actual)
                SELECT id,saldo_inicial FROM cuentas_gestion WHERE id=?
                ON CONFLICT (cuenta_id) DO NOTHING
                """, id);
        // El saldo queda bloqueado hasta el commit de la solicitud.
        if (jdbc.queryForList("SELECT cuenta_id FROM pagos_saldos WHERE cuenta_id=? FOR UPDATE", id).isEmpty()) {
            throw new IllegalStateException("No se pudo bloquear el saldo de cuenta " + id);
        }
    }

    private void registrarMovimiento(UUID id, long cuentaId, String sentido, BigDecimal monto) {
        int n = jdbc.update("""
                INSERT INTO pagos_movimientos(solicitud_id,cuenta_id,sentido,monto)
                VALUES (?,?,?,?)
                """, id, cuentaId, sentido, monto);
        if (n != 1) throw new IllegalStateException("Error registrando movimiento");
    }

    @Transactional(readOnly = true)
    public Estado consultar(UUID id) {
        List<Estado> estados = jdbc.query("""
                SELECT id,tipo,monto,estado FROM pagos_solicitudes WHERE id=?
                """, (rs, n) -> new Estado(rs.getObject("id", UUID.class),
                Tipo.valueOf(rs.getString("tipo")), rs.getBigDecimal("monto"),
                rs.getString("estado")), id);
        return estados.stream().findFirst().orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Solicitud no encontrada"));
    }

    @Transactional(readOnly = true)
    public SaldoCuenta saldo(long cuentaId) {
        List<SaldoCuenta> saldos = jdbc.query("""
                SELECT g.id, COALESCE(p.saldo_actual,g.saldo_inicial) AS saldo
                FROM cuentas_gestion g LEFT JOIN pagos_saldos p ON p.cuenta_id=g.id
                WHERE g.id=?
                """, (rs, n) -> new SaldoCuenta(rs.getLong("id"), rs.getBigDecimal("saldo")), cuentaId);
        return saldos.stream().findFirst().orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Cuenta no encontrada"));
    }
}
