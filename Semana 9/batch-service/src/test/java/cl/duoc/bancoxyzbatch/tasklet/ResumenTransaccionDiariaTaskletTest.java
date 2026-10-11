package cl.duoc.bancoxyzbatch.tasklet;

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
