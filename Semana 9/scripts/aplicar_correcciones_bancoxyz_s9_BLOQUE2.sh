#!/usr/bin/env bash
# BancoXYZ S9 - BLOQUE 2. Ejecutar desde Fish con: bash ~/Descargas/aplicar_correcciones_bancoxyz_s9_BLOQUE2.sh
# Solo cambia 2 clases Java y crea 2 tests JUnit. No ejecuta comandos SQL, Docker, ni toca CSV.
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
    echo 'ERROR: falta python3. No se ha cambiado nada.' >&2
    exit 2
fi

python3 - "$PWD" <<'PY'
from pathlib import Path
import sys
import re

root = Path(sys.argv[1]).resolve()
s9 = root / 'Semana 9'
if not s9.is_dir():
    print('ERROR: ejecuta este .sh desde la raíz de bancoxyzbatch (debe existir Semana 9/).', file=sys.stderr)
    sys.exit(2)

# Cada archivo modificado se revisa primero por completo. Si diverge o hay conflicto,
# abortamos ANTES de escribir. No se crean backups, ni snapshots, ni ficheros SQL.
changes = {}

def expect_replace(path: Path, before: str, after: str, label: str):
    content = changes.get(path, path.read_text(encoding='utf-8'))
    if after in content:
        changes[path] = content
        return
    if before in content:
        if content.count(before) != 1:
            raise RuntimeError(f'{label}: bloque ambiguo ({content.count(before)} coincidencias): {path}')
        changes[path] = content.replace(before, after, 1)
        return
    raise RuntimeError(f'{label}: el contenido local no coincide con el ZIP auditado. No se modifica nada: {path}')

# 1. El borrado y la regeneración del resumen deben compartir una sola transacción.
summary = s9 / 'batch-service/src/main/java/cl/duoc/bancoxyzbatch/tasklet/ResumenTransaccionDiariaTasklet.java'
service = s9 / 'bank-backend/src/main/java/cl/duoc/bancoxyz/backend/service/CuentaInteresService.java'

batch_test = s9 / 'batch-service/src/test/java/cl/duoc/bancoxyzbatch/tasklet/ResumenTransaccionDiariaTaskletTest.java'
retreat_test = s9 / 'bank-backend/src/test/java/cl/duoc/bancoxyz/backend/service/CuentaInteresServiceTest.java'

for path in (summary, service):
    if not path.is_file():
        raise RuntimeError(f'Falta archivo original requerido: {path}')

expect_replace(
    summary,
    'import org.springframework.stereotype.Component;',
    'import org.springframework.stereotype.Component;\nimport org.springframework.transaction.annotation.Transactional;',
    'import transaccional de resumen Batch'
)
expect_replace(
    summary,
    '    @Override\n    public RepeatStatus execute(',
    '    // Eliminar y recalcular el reporte derivado es una operación atómica.\n    @Override\n    @Transactional\n    public RepeatStatus execute(',
    'Atomicidad del tasklet'
)

# 2. Nunca publicar un retiro si su transacción SQL aún puede fallar.
#    Se mantiene el contrato actual; la publicación es BEST-EFFORT después del commit.
#    No equivale a entrega garantizada ni introduce Outbox.
expect_replace(
    service,
    'import org.springframework.transaction.annotation.Transactional;',
    'import org.springframework.transaction.annotation.Transactional;\nimport org.springframework.transaction.support.TransactionSynchronization;\nimport org.springframework.transaction.support.TransactionSynchronizationManager;',
    'import sincronización transaccional'
)
expect_replace(
    service,
    '''        retiroKafkaProducer.publicarRetiro(evento);

        return cuentaActualizada;''',
    '''        // El evento no se publica hasta que PostgreSQL confirma el saldo.
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

        return cuentaActualizada;''',
    'Kafka después del commit'
)

# Prueba de que el resumen es repetible y no duplica transacciones inválidas.
batch_test_body = '''package cl.duoc.bancoxyzbatch.tasklet;

import cl.duoc.bancoxyzbatch.model.ResumenTransaccionDiaria;
import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;
import cl.duoc.bancoxyzbatch.repository.ResumenTransaccionDiariaRepository;
import cl.duoc.bancoxyzbatch.repository.TransaccionProcesadaRepository;
import org.junit.jupiter.api.Test;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.scope.context.StepContext;
import org.springframework.batch.core.step.StepContribution;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class ResumenTransaccionDiariaTaskletTest {

    @Test
    void reconstruccionDosVecesNoAcumulaMontosDeEjecucionesAnteriores() throws Exception {
        var transacciones = mock(TransaccionProcesadaRepository.class);
        var resumenes = mock(ResumenTransaccionDiariaRepository.class);
        var tasklet = new ResumenTransaccionDiariaTasklet(transacciones, resumenes);
        var contexto = mock(ChunkContext.class);
        var paso = mock(StepContext.class);
        when(contexto.getStepContext()).thenReturn(paso);
        when(paso.getJobInstanceId()).thenReturn(1L);

        var fecha = LocalDate.of(2026, 1, 15);
        when(transacciones.findByActivoTrueOrderByFechaAscIdAsc()).thenReturn(List.of(
                movimiento(1L, fecha, "credito", "VALIDO", "100.00"),
                movimiento(2L, fecha, "debito", "VALIDO", "25.00"),
                movimiento(3L, fecha, "credito", "DUPLICADO", "100.00"),
                movimiento(4L, fecha, "credito", "RECHAZADO", "100.00")
        ));

        List<List<ResumenTransaccionDiaria>> capturas = new ArrayList<>();
        doAnswer(invocacion -> {
            Iterable<ResumenTransaccionDiaria> datos = invocacion.getArgument(0);
            List<ResumenTransaccionDiaria> lista = new ArrayList<>();
            datos.forEach(lista::add);
            capturas.add(lista);
            return List.of();
        }).when(resumenes).saveAll(any());

        tasklet.execute(mock(StepContribution.class), contexto);
        tasklet.execute(mock(StepContribution.class), contexto);

        verify(resumenes, times(2)).deleteAllInBatch();
        assertEquals(2, capturas.size());
        for (var corrida : capturas) {
            assertEquals(1, corrida.size());
            var resumen = corrida.get(0);
            assertEquals(Long.valueOf(2L), resumen.getCantidadTransacciones());
            assertEquals(0, new BigDecimal("100.00").compareTo(resumen.getTotalCreditos()));
            assertEquals(0, new BigDecimal("25.00").compareTo(resumen.getTotalDebitos()));
            assertEquals(0, new BigDecimal("75.00").compareTo(resumen.getSaldoNeto()));
        }
    }

    private static TransaccionProcesada movimiento(
            long id, LocalDate fecha, String tipo, String estado, String monto) {
        var item = new TransaccionProcesada();
        item.setId(id);
        item.setFecha(fecha);
        item.setTipo(tipo);
        item.setEstado(estado);
        item.setMonto(new BigDecimal(monto));
        item.setActivo(true);
        return item;
    }
}
'''

# Prueba de publicación tras commit y no-publicación tras rollback.
retreat_test_body = '''package cl.duoc.bancoxyz.backend.service;

import cl.duoc.bancoxyz.backend.entity.CuentaInteres;
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

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class CuentaInteresServiceTest {

    private final CuentaInteresRepository repository = mock(CuentaInteresRepository.class);
    private final RetiroKafkaProducer producer = mock(RetiroKafkaProducer.class);
    private final CuentaInteresService service = new CuentaInteresService(repository, producer);

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

        TransactionSynchronizationManager.getSynchronizations()
                .forEach(TransactionSynchronization::afterCommit);
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

    private void prepararCuenta() {
        var cuenta = new CuentaInteres();
        cuenta.setCuentaId(11L);
        cuenta.setActivo(true);
        cuenta.setSaldoFinal(new BigDecimal("100.00"));
        when(repository.findByIdForUpdate(11L)).thenReturn(Optional.of(cuenta));
        when(repository.saveAndFlush(any(CuentaInteres.class))).thenAnswer(a -> a.getArgument(0));
    }
}
'''

# Tests nuevos: nunca sobrescribimos archivos del usuario que hayan evolucionado.
for path, desired in [(batch_test, batch_test_body), (retreat_test, retreat_test_body)]:
    if path.exists() and path.read_text(encoding='utf-8') != desired:
        raise RuntimeError(f'Existe una prueba diferente; no la sobrescribo: {path}')
    changes[path] = desired

# Protección final: destinos acotados; nunca se modifican CSV, SQL, respaldos ni ZIP.
allowed_suffixes = {'.java'}
for path in changes:
    if path.suffix not in allowed_suffixes or s9 not in path.parents:
        raise RuntimeError(f'Ruta de salida no permitida: {path}')

pending = [(path, contents) for path, contents in changes.items()
           if not path.exists() or path.read_text(encoding='utf-8') != contents]
if not pending:
    print('OK: BLOQUE 2 ya aplicado. No se modificó nada. Código de salida 0.')
    sys.exit(0)

# Preflight completo superado: escribimos las clases y pruebas de forma local.
for path, contents in pending:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents, encoding='utf-8')
    print('APLICADO:', path.relative_to(root))

print('\nOK: BLOQUE 2 instalado. No se ejecutaron jobs, Docker, Kafka ni SQL.')
print('OK: Ningún CSV, snapshot o base de datos fue modificado.')
print('PENDIENTE: compilar y ejecutar tests Maven en tu entorno, y hacer pruebas integradas.')
print('PENDIENTE: idempotencia de retiros y entrega garantizada Kafka requieren diseño y DB.')
print('PENDIENTE: pagos monetarios reales y consolidación de DB NO están incluidos.')
PY
