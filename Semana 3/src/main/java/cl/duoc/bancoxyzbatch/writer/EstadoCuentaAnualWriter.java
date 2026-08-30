package cl.duoc.bancoxyzbatch.writer;

import cl.duoc.bancoxyzbatch.config.BatchRunContext;
import cl.duoc.bancoxyzbatch.model.MovimientoAnual;

import org.springframework.batch.infrastructure.item.Chunk;
import org.springframework.batch.infrastructure.item.ItemWriter;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * Consolido los movimientos anuales mediante un UPSERT atómico en PostgreSQL.
 * Esto evita pérdidas de actualización durante el procesamiento paralelo.
 */
@Component
public class EstadoCuentaAnualWriter
        implements ItemWriter<MovimientoAnual> {

    private static final String UPSERT_SQL = """
            INSERT INTO estados_cuenta_anuales (
                cuenta_id,
                anio,
                total_depositos,
                total_retiros,
                total_compras,
                saldo_anual,
                activo,
                ultima_instancia_id
            )
            VALUES (?, ?, ?, ?, ?, ?, TRUE, ?)

            ON CONFLICT (cuenta_id, anio)

            DO UPDATE SET

                total_depositos = CASE
                    WHEN estados_cuenta_anuales.ultima_instancia_id
                         = EXCLUDED.ultima_instancia_id
                    THEN estados_cuenta_anuales.total_depositos
                         + EXCLUDED.total_depositos
                    ELSE EXCLUDED.total_depositos
                END,

                total_retiros = CASE
                    WHEN estados_cuenta_anuales.ultima_instancia_id
                         = EXCLUDED.ultima_instancia_id
                    THEN estados_cuenta_anuales.total_retiros
                         + EXCLUDED.total_retiros
                    ELSE EXCLUDED.total_retiros
                END,

                total_compras = CASE
                    WHEN estados_cuenta_anuales.ultima_instancia_id
                         = EXCLUDED.ultima_instancia_id
                    THEN estados_cuenta_anuales.total_compras
                         + EXCLUDED.total_compras
                    ELSE EXCLUDED.total_compras
                END,

                saldo_anual = CASE
                    WHEN estados_cuenta_anuales.ultima_instancia_id
                         = EXCLUDED.ultima_instancia_id
                    THEN estados_cuenta_anuales.saldo_anual
                         + EXCLUDED.saldo_anual
                    ELSE EXCLUDED.saldo_anual
                END,

                activo = TRUE,
                ultima_instancia_id =
                    EXCLUDED.ultima_instancia_id
            """;

    private final JdbcTemplate jdbcTemplate;
    private final BatchRunContext runContext;

    public EstadoCuentaAnualWriter(
            JdbcTemplate jdbcTemplate,
            BatchRunContext runContext
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.runContext = runContext;
    }

    @Override
    public void write(
            Chunk<? extends MovimientoAnual> chunk
    ) {

        if (chunk.isEmpty()) {
            return;
        }

        Long jobInstanceId =
                runContext.getJobInstanceId();

        System.out.println(
                "[BATCH-WRITER] hilo="
                        + Thread.currentThread().getName()
                        + " | chunk="
                        + chunk.size()
                        + " | jobInstance="
                        + jobInstanceId
        );

        /*
         * Agrupo los parámetros para realizar
         * las escrituras mediante batchUpdate.
         */
        List<Object[]> parametros =
                new ArrayList<>();

        for (MovimientoAnual movimiento :
                chunk) {

            BigDecimal totalDepositos =
                    BigDecimal.ZERO;

            BigDecimal totalRetiros =
                    BigDecimal.ZERO;

            BigDecimal totalCompras =
                    BigDecimal.ZERO;

            BigDecimal monto =
                    movimiento.getMonto();

            switch (
                    movimiento.getTransaccion()
            ) {

                case "deposito" ->
                        totalDepositos =
                                monto.abs();

                case "retiro" ->
                        totalRetiros =
                                monto.abs();

                case "compra" ->
                        totalCompras =
                                monto.abs();

                default ->
                        throw new IllegalArgumentException(
                                "Tipo de movimiento no soportado: "
                                        + movimiento.getTransaccion()
                        );
            }

            parametros.add(
                    new Object[]{
                            movimiento.getCuentaId(),
                            movimiento.getFecha()
                                    .getYear(),
                            totalDepositos,
                            totalRetiros,
                            totalCompras,
                            monto,
                            jobInstanceId
                    }
            );
        }

        /*
         * PostgreSQL resuelve la actualización de forma atómica.
         * En una misma corrida acumulo valores; en una nueva,
         * el primer movimiento reemplaza los totales anteriores.
         */
        jdbcTemplate.batchUpdate(
                UPSERT_SQL,
                parametros
        );
    }
}
