package cl.duoc.bancoxyzbatch.config;

import cl.duoc.bancoxyzbatch.model.MovimientoAnual;
import cl.duoc.bancoxyzbatch.util.CsvValueParser;
import org.springframework.batch.infrastructure.item.file.FlatFileItemReader;
import org.springframework.batch.infrastructure.item.file.builder.FlatFileItemReaderBuilder;
import org.springframework.batch.infrastructure.item.support.SynchronizedItemStreamReader;
import org.springframework.batch.infrastructure.item.support.builder.SynchronizedItemStreamReaderBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

/**
 * Configuro la lectura de los movimientos utilizados para generar
 * los estados de cuenta anuales.
 *
 * El CSV legacy puede contener distintos formatos de fecha, montos vacíos
 * y campos opcionales. La conversión tolerante permite transportar dichos
 * valores hasta el ItemProcessor sin interrumpir prematuramente el Job.
 *
 * El reader permanece sincronizado para mantener una lectura consistente
 * durante el procesamiento paralelo.
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
                                    CsvValueParser.parseLong(
                                            fieldSet.readString(
                                                    "cuenta_id"
                                            )
                                    )
                            );

                            movimiento.setFecha(
                                    CsvValueParser.parseLocalDate(
                                            fieldSet.readString(
                                                    "fecha"
                                            )
                                    )
                            );

                            movimiento.setTransaccion(
                                    CsvValueParser.parseString(
                                            fieldSet.readString(
                                                    "transaccion"
                                            )
                                    )
                            );

                            movimiento.setMonto(
                                    CsvValueParser.parseBigDecimal(
                                            fieldSet.readString(
                                                    "monto"
                                            )
                                    )
                            );

                            movimiento.setDescripcion(
                                    CsvValueParser.parseString(
                                            fieldSet.readString(
                                                    "descripcion"
                                            )
                                    )
                            );

                            return movimiento;
                        })
                        .build();

        /*
         * FlatFileItemReader mantiene un cursor interno.
         * La sincronización evita accesos simultáneos durante
         * la ejecución con múltiples hilos.
         */
        return new SynchronizedItemStreamReaderBuilder<MovimientoAnual>()
                .delegate(delegate)
                .build();
    }
}
