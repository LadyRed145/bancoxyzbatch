package cl.duoc.bancoxyz.backend.service;

import cl.duoc.bancoxyz.backend.entity.CuentaInteres;
import cl.duoc.bancoxyz.backend.entity.RetiroIdempotencia;
import cl.duoc.bancoxyz.backend.repository.RetiroIdempotenciaRepository;
import cl.duoc.bancoxyz.backend.kafka.RetiroKafkaProducer;
import cl.duoc.bancoxyz.backend.repository.CuentaInteresRepository;
import cl.duoc.bancoxyz.event.RetiroRealizadoEvent;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class CuentaInteresServiceTest {

    private final CuentaInteresRepository repository = mock(CuentaInteresRepository.class);
    private final RetiroKafkaProducer producer = mock(RetiroKafkaProducer.class);
    private final RetiroIdempotenciaRepository recibos = mock(RetiroIdempotenciaRepository.class);
    private final CuentaInteresService service = new CuentaInteresService(repository, producer, recibos);

    @BeforeEach
    void prepararTransaccionSimulada() {
        TransactionSynchronizationManager.initSynchronization();
        TransactionSynchronizationManager.setActualTransactionActive(true);
    }

    @AfterEach
    void limpiarTransaccionSimulada() {
        TransactionSynchronizationManager.clearSynchronization();
        TransactionSynchronizationManager.setActualTransactionActive(false);
    }

    @Test
    void noPublicaAntesDelCommitNiTrasRollback() {
        prepararCuenta();
        service.retirar(11L, new BigDecimal("10.00"));
        verifyNoInteractions(producer);
        assertEquals(1, TransactionSynchronizationManager.getSynchronizations().size());

        TransactionSynchronizationManager.getSynchronizations()
                .forEach(s -> s.afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK));
        verifyNoInteractions(producer);
    }

    @Test
    void publicaSoloDespuesDeCommitConfirmado() {
        prepararCuenta();
        service.retirar(11L, new BigDecimal("10.00"));
        verifyNoInteractions(producer);

        for (TransactionSynchronization synchronization : TransactionSynchronizationManager.getSynchronizations()) {
            synchronization.afterCommit();
        }
        verify(producer, times(1)).publicarRetiro(any(RetiroRealizadoEvent.class));
    }

    @Test
    void fondosInsuficientesNuncaAgendaEvento() {
        prepararCuenta();
        assertThrows(RuntimeException.class,
                () -> service.retirar(11L, new BigDecimal("150.00")));
        verifyNoInteractions(producer);
        assertTrue(TransactionSynchronizationManager.getSynchronizations().isEmpty());
    }

    @Test
    void reintentoConMismaClaveNoDescuentaNiPublica() {
        var clave = UUID.randomUUID();
        prepararCuenta();
        when(recibos.findById(clave)).thenReturn(Optional.of(
                new RetiroIdempotencia(clave, 11L,
                        new BigDecimal("10.00"), new BigDecimal("90.00"))));
        var resultado = service.retirar(11L, new BigDecimal("10.00"), clave);
        assertEquals(0, new BigDecimal("100.00").compareTo(resultado.getSaldoFinal()));
        verify(repository, never()).saveAndFlush(any());
        assertTrue(TransactionSynchronizationManager.getSynchronizations().isEmpty());
        verifyNoInteractions(producer);
    }

    @Test
    void claveReutilizadaConOtroMontoEsConflicto() {
        var clave = UUID.randomUUID();
        prepararCuenta();
        when(recibos.findById(clave)).thenReturn(Optional.of(
                new RetiroIdempotencia(clave, 11L,
                        new BigDecimal("10.00"), new BigDecimal("90.00"))));
        var error = assertThrows(org.springframework.web.server.ResponseStatusException.class,
                () -> service.retirar(11L, new BigDecimal("20.00"), clave));
        assertEquals(409, error.getStatusCode().value());
        verify(repository, never()).saveAndFlush(any());
    }

    private void prepararCuenta() {
        var cuenta = new CuentaInteres();
        cuenta.setCuentaId(11L);
        cuenta.setActivo(true);
        cuenta.setSaldoFinal(new BigDecimal("100.00"));
        when(repository.findByIdForUpdate(11L)).thenReturn(Optional.of(cuenta));
        when(repository.saveAndFlush(any(CuentaInteres.class))).thenAnswer(a -> a.getArgument(0));
    }
}
