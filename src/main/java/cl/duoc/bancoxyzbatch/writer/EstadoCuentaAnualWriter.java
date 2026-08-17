package cl.duoc.bancoxyzbatch.writer;

import cl.duoc.bancoxyzbatch.config.BatchRunContext;
import cl.duoc.bancoxyzbatch.model.EstadoCuentaAnual;
import cl.duoc.bancoxyzbatch.model.MovimientoAnual;
import cl.duoc.bancoxyzbatch.repository.EstadoCuentaAnualRepository;
import org.springframework.batch.infrastructure.item.Chunk;
import org.springframework.batch.infrastructure.item.ItemWriter;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

@Component
public class EstadoCuentaAnualWriter
        implements ItemWriter<MovimientoAnual> {

    private final EstadoCuentaAnualRepository repository;
    private final BatchRunContext runContext;

    public EstadoCuentaAnualWriter(
            EstadoCuentaAnualRepository repository,
            BatchRunContext runContext
    ) {
        this.repository = repository;
        this.runContext = runContext;
    }

    @Override
    public void write(
            Chunk<? extends MovimientoAnual> chunk
    ) {

        if (chunk.isEmpty()) {
            return;
        }

        Map<CuentaAnioKey, EstadoCuentaAnual> acumulados =
                new HashMap<>();

        for (MovimientoAnual movimiento : chunk) {

            Long cuentaId = movimiento.getCuentaId();
            Integer anio = movimiento.getFecha().getYear();

            CuentaAnioKey key =
                    new CuentaAnioKey(cuentaId, anio);

            EstadoCuentaAnual estado =
                    acumulados.computeIfAbsent(
                            key,
                            ignored ->
                                    cargarEstado(cuentaId, anio)
                    );

            procesarMovimiento(
                    estado,
                    movimiento
            );
        }

        repository.saveAll(acumulados.values());
    }

    private EstadoCuentaAnual cargarEstado(
            Long cuentaId,
            Integer anio
    ) {

        EstadoCuentaAnual estado = repository
                .findByCuentaIdAndAnio(cuentaId, anio)
                .orElseGet(
                        () -> crearEstado(cuentaId, anio)
                );

        Long instanciaActual =
                runContext.getJobInstanceId();

        /*
         * Si pertenece a una corrida lógica anterior,
         * recalculamos este consolidado desde cero.
         *
         * Si pertenece a la misma JobInstance,
         * conservamos lo acumulado porque puede ser
         * otro chunk o un reinicio del mismo Job.
         */
        if (!Objects.equals(
                estado.getUltimaInstanciaId(),
                instanciaActual
        )) {
            reiniciarTotales(estado);
        }

        estado.setActivo(true);
        estado.setUltimaInstanciaId(instanciaActual);

        return estado;
    }

    private EstadoCuentaAnual crearEstado(
            Long cuentaId,
            Integer anio
    ) {

        EstadoCuentaAnual estado =
                new EstadoCuentaAnual();

        estado.setCuentaId(cuentaId);
        estado.setAnio(anio);

        reiniciarTotales(estado);

        estado.setActivo(true);
        estado.setUltimaInstanciaId(
                runContext.getJobInstanceId()
        );

        return estado;
    }

    private void reiniciarTotales(
            EstadoCuentaAnual estado
    ) {
        estado.setTotalDepositos(BigDecimal.ZERO);
        estado.setTotalRetiros(BigDecimal.ZERO);
        estado.setTotalCompras(BigDecimal.ZERO);
        estado.setSaldoAnual(BigDecimal.ZERO);
    }

    private void procesarMovimiento(
            EstadoCuentaAnual estado,
            MovimientoAnual movimiento
    ) {

        BigDecimal monto = movimiento.getMonto();

        switch (movimiento.getTransaccion()) {

            case "deposito" ->
                    estado.setTotalDepositos(
                            estado.getTotalDepositos()
                                    .add(monto.abs())
                    );

            case "retiro" ->
                    estado.setTotalRetiros(
                            estado.getTotalRetiros()
                                    .add(monto.abs())
                    );

            case "compra" ->
                    estado.setTotalCompras(
                            estado.getTotalCompras()
                                    .add(monto.abs())
                    );

            default ->
                    throw new IllegalArgumentException(
                            "Tipo de movimiento no soportado: "
                                    + movimiento.getTransaccion()
                    );
        }

        estado.setSaldoAnual(
                estado.getSaldoAnual()
                        .add(monto)
        );
    }

    private record CuentaAnioKey(
            Long cuentaId,
            Integer anio
    ) {
    }
}
