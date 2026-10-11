package cl.duoc.bancoxyz.backend.service;

import cl.duoc.bancoxyz.backend.entity.CuentaInteres;
import cl.duoc.bancoxyz.backend.entity.RetiroIdempotencia;
import cl.duoc.bancoxyz.backend.repository.RetiroIdempotenciaRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import cl.duoc.bancoxyz.backend.exception.CuentaInactivaException;
import cl.duoc.bancoxyz.backend.exception.CuentaNoEncontradaException;
import cl.duoc.bancoxyz.backend.exception.SaldoInsuficienteException;
import cl.duoc.bancoxyz.backend.kafka.RetiroKafkaProducer;
import cl.duoc.bancoxyz.backend.repository.CuentaInteresRepository;
import cl.duoc.bancoxyz.event.RetiroRealizadoEvent;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Servicio de cuentas: valida el retiro, persiste el nuevo saldo y delega la
 * publicación del evento Kafka al producer dedicado.
 */
@Service
public class CuentaInteresService {

    private final CuentaInteresRepository repository;
    private final RetiroKafkaProducer retiroKafkaProducer;
    private final RetiroIdempotenciaRepository recibos;

    public CuentaInteresService(
            CuentaInteresRepository repository,
            RetiroKafkaProducer retiroKafkaProducer,
            RetiroIdempotenciaRepository recibos) {

        this.repository = repository;
        this.retiroKafkaProducer = retiroKafkaProducer;
        this.recibos = recibos;
    }

    public List<CuentaInteres> obtenerTodas() {
        return repository.findAll();
    }

    public Optional<CuentaInteres> obtenerPorId(Long id) {
        return repository.findById(id);
    }

    @Transactional
    public CuentaInteres retirar(Long cuentaId, BigDecimal monto) {
        return retirar(cuentaId, monto, null);
    }

    /** Si el cliente incluye Idempotency-Key, un reintento no repite el débito. */
    @Transactional
    public CuentaInteres retirar(Long cuentaId, BigDecimal monto, UUID clave) {

        if (monto == null || monto.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("El monto debe ser mayor a cero");
        }

        CuentaInteres cuenta = repository.findByIdForUpdate(cuentaId)
                .orElseThrow(() -> new CuentaNoEncontradaException(cuentaId));

        // Se consulta BAJO el lock de cuenta para serializar los reintentos.
        // El registro del recibo y el descuento comparten transacción SQL.
        if (clave != null) {
            Optional<RetiroIdempotencia> anterior = recibos.findById(clave);
            if (anterior.isPresent()) {
                RetiroIdempotencia r = anterior.get();
                if (!r.getCuentaId().equals(cuentaId) || r.getMonto().compareTo(monto) != 0) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT,
                            "Idempotency-Key ya utilizada en una operación distinta");
                }
                // No se descuenta ni se emite un segundo evento Kafka.
                return cuenta;
            }
        }

        if (!Boolean.TRUE.equals(cuenta.getActivo())) {
            throw new CuentaInactivaException(cuentaId);
        }

        if (cuenta.getSaldoFinal().compareTo(monto) < 0) {
            throw new SaldoInsuficienteException(cuentaId);
        }

        cuenta.setSaldoFinal(
                cuenta.getSaldoFinal().subtract(monto)
        );

        CuentaInteres cuentaActualizada = repository.saveAndFlush(cuenta);
        if (clave != null) {
            // El INSERT será revertido si la transacción del retiro falla.
            recibos.saveAndFlush(new RetiroIdempotencia(
                    clave, cuentaId, monto, cuentaActualizada.getSaldoFinal()));
        }

        RetiroRealizadoEvent evento = new RetiroRealizadoEvent(
                cuentaId,
                monto,
                cuentaActualizada.getSaldoFinal(),
                "RETIRO"
        );

        // El evento no se publica hasta que PostgreSQL confirma el saldo.
        // Si la transacción hace rollback, no se enviará a Kafka.
        // Esto NO garantiza reintentos durables tras un fallo de Kafka;
        // esa garantía requiere una decisión posterior de diseño.
        if (!TransactionSynchronizationManager.isActualTransactionActive()
                || !TransactionSynchronizationManager.isSynchronizationActive()) {
            throw new IllegalStateException(
                    "El retiro requiere una transacción activa para publicar Kafka tras el commit"
            );
        }

        TransactionSynchronizationManager.registerSynchronization(
                new TransactionSynchronization() {
                    @Override
                    public void afterCommit() {
                        retiroKafkaProducer.publicarRetiro(evento);
                    }
                }
        );

        return cuentaActualizada;
    }
}
