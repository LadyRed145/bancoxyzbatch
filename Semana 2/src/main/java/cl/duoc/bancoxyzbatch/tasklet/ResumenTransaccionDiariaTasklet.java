package cl.duoc.bancoxyzbatch.tasklet;

import cl.duoc.bancoxyzbatch.model.ResumenTransaccionDiaria;
import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;
import cl.duoc.bancoxyzbatch.repository.ResumenTransaccionDiariaRepository;
import cl.duoc.bancoxyzbatch.repository.TransaccionProcesadaRepository;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.StepContribution;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.infrastructure.repeat.RepeatStatus;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class ResumenTransaccionDiariaTasklet
        implements Tasklet {

    private final TransaccionProcesadaRepository transaccionRepository;
    private final ResumenTransaccionDiariaRepository resumenRepository;

    public ResumenTransaccionDiariaTasklet(
            TransaccionProcesadaRepository transaccionRepository,
            ResumenTransaccionDiariaRepository resumenRepository
    ) {
        this.transaccionRepository = transaccionRepository;
        this.resumenRepository = resumenRepository;
    }

    @Override
    public RepeatStatus execute(
            StepContribution contribution,
            ChunkContext chunkContext
    ) {

        Long jobInstanceId =
                chunkContext
                        .getStepContext()
                        .getJobInstanceId();

        List<TransaccionProcesada> transacciones =
                transaccionRepository
                        .findByActivoTrueOrderByFechaAscIdAsc();

        Map<LocalDate, ResumenTransaccionDiaria> resumenes =
                new LinkedHashMap<>();

        for (TransaccionProcesada transaccion : transacciones) {

            /*
             * Los registros rechazados no representan
             * movimientos financieros válidos.
             *
             * Los duplicados tampoco deben volver a sumarse,
             * para evitar inflar artificialmente el reporte.
             */
            if ("RECHAZADO".equals(transaccion.getEstado())
                    || "DUPLICADO".equals(transaccion.getEstado())) {
                continue;
            }

            ResumenTransaccionDiaria resumen =
                    resumenes.computeIfAbsent(
                            transaccion.getFecha(),
                            fecha -> nuevoResumen(
                                    fecha,
                                    jobInstanceId
                            )
                    );

            resumen.setCantidadTransacciones(
                    resumen.getCantidadTransacciones() + 1
            );

            if ("credito".equals(transaccion.getTipo())) {

                resumen.setTotalCreditos(
                        resumen.getTotalCreditos()
                                .add(transaccion.getMonto())
                );

            } else if ("debito".equals(transaccion.getTipo())) {

                resumen.setTotalDebitos(
                        resumen.getTotalDebitos()
                                .add(transaccion.getMonto())
                );
            }

            resumen.setSaldoNeto(
                    resumen.getTotalCreditos()
                            .subtract(resumen.getTotalDebitos())
            );
        }

        /*
         * Es una tabla derivada/reporte.
         * Se reconstruye desde el estado vigente de las
         * transacciones procesadas para garantizar idempotencia.
         */
        resumenRepository.deleteAllInBatch();
        resumenRepository.saveAll(resumenes.values());

        return RepeatStatus.FINISHED;
    }

    private ResumenTransaccionDiaria nuevoResumen(
            LocalDate fecha,
            Long jobInstanceId
    ) {

        ResumenTransaccionDiaria resumen =
                new ResumenTransaccionDiaria();

        resumen.setFecha(fecha);
        resumen.setCantidadTransacciones(0L);
        resumen.setTotalCreditos(BigDecimal.ZERO);
        resumen.setTotalDebitos(BigDecimal.ZERO);
        resumen.setSaldoNeto(BigDecimal.ZERO);
        resumen.setUltimaInstanciaId(jobInstanceId);

        return resumen;
    }
}
