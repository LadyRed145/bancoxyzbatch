package cl.duoc.bancoxyzbatch.config;

import cl.duoc.bancoxyzbatch.model.MovimientoAnual;
import org.springframework.batch.infrastructure.item.file.FlatFileItemReader;
import org.springframework.batch.infrastructure.item.file.builder.FlatFileItemReaderBuilder;
import org.springframework.batch.infrastructure.item.support.SynchronizedItemStreamReader;
import org.springframework.batch.infrastructure.item.support.builder.SynchronizedItemStreamReaderBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Configuro la lectura de los movimientos anuales.
 * El reader sincronizado evita inconsistencias durante la ejecución paralela.
 */
@Configuration
public class MovimientoAnualReaderConfig {

    @Bean(name = "movimientoAnualReader")
    public SynchronizedItemStreamReader<MovimientoAnual>
    movimientoAnualReader() {

        FlatFileItemReader<MovimientoAnual> delegate =
                new FlatFileItemReaderBuilder<MovimientoAnual>()
                        .name(
                                "movimientoAnualFlatFileReader"
                        )
                        .resource(
                                new ClassPathResource(
                                        "data/cuentas_anuales.csv"
                                )
                        )
                        .linesToSkip(1)
                        .delimited()
                        .delimiter(",")
                        .names(
                                "cuenta_id",
                                "fecha",
                                "transaccion",
                                "monto",
                                "descripcion"
                        )
                        .fieldSetMapper(fieldSet -> {

                            MovimientoAnual movimiento =
                                    new MovimientoAnual();

                            movimiento.setCuentaId(
                                    Long.valueOf(
                                            fieldSet
                                                    .readString("cuenta_id")
                                                    .trim()
                                    )
                            );

                            movimiento.setFecha(
                                    LocalDate.parse(
                                            fieldSet
                                                    .readString("fecha")
                                                    .trim()
                                    )
                            );

                            movimiento.setTransaccion(
                                    fieldSet
                                            .readString("transaccion")
                                            .trim()
                            );

                            movimiento.setMonto(
                                    new BigDecimal(
                                            fieldSet
                                                    .readString("monto")
                                                    .trim()
                                    )
                            );

                            movimiento.setDescripcion(
                                    fieldSet
                                            .readString("descripcion")
                                            .trim()
                            );

                            return movimiento;
                        })
                        .build();

        return new SynchronizedItemStreamReaderBuilder<MovimientoAnual>()
                .delegate(delegate)
                .build();
    }
}
