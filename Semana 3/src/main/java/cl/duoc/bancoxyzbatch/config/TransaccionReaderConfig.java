package cl.duoc.bancoxyzbatch.config;

import cl.duoc.bancoxyzbatch.model.Transaccion;
import cl.duoc.bancoxyzbatch.util.CsvValueParser;
import org.springframework.batch.infrastructure.item.file.FlatFileItemReader;
import org.springframework.batch.infrastructure.item.file.builder.FlatFileItemReaderBuilder;
import org.springframework.batch.infrastructure.item.support.SynchronizedItemStreamReader;
import org.springframework.batch.infrastructure.item.support.builder.SynchronizedItemStreamReaderBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

/**
 * Configuro la lectura del CSV de transacciones.
 *
 * La conversión de los valores legacy se realiza de forma tolerante para
 * evitar que un dato vacío, mal formado o con un formato alternativo detenga
 * la lectura completa del archivo.
 *
 * Las validaciones y reglas de negocio se mantienen en el ItemProcessor.
 *
 * Sincronizo el reader para utilizarlo de forma segura con varios hilos.
 */
@Configuration
public class TransaccionReaderConfig {

    @Bean(name = "transaccionReader")
    public SynchronizedItemStreamReader<Transaccion>
    transaccionReader() {

        FlatFileItemReader<Transaccion> delegate =
                new FlatFileItemReaderBuilder<Transaccion>()
                        .name(
                                "transaccionFlatFileReader"
                        )
                        .resource(
                                new ClassPathResource(
                                        "data/transacciones.csv"
                                )
                        )
                        .linesToSkip(1)
                        .delimited()
                        .delimiter(",")
                        .names(
                                "id",
                                "fecha",
                                "monto",
                                "tipo"
                        )
                        .fieldSetMapper(fieldSet -> {

                            Transaccion transaccion =
                                    new Transaccion();

                            transaccion.setId(
                                    CsvValueParser.parseLong(
                                            fieldSet.readString(
                                                    "id"
                                            )
                                    )
                            );

                            transaccion.setFecha(
                                    CsvValueParser.parseLocalDate(
                                            fieldSet.readString(
                                                    "fecha"
                                            )
                                    )
                            );

                            transaccion.setMonto(
                                    CsvValueParser.parseBigDecimal(
                                            fieldSet.readString(
                                                    "monto"
                                            )
                                    )
                            );

                            transaccion.setTipo(
                                    CsvValueParser.parseString(
                                            fieldSet.readString(
                                                    "tipo"
                                            )
                                    )
                            );

                            return transaccion;
                        })
                        .build();

        /*
         * FlatFileItemReader mantiene estado interno.
         * Lo sincronizo para evitar lecturas concurrentes inconsistentes.
         */
        return new SynchronizedItemStreamReaderBuilder<Transaccion>()
                .delegate(delegate)
                .build();
    }
}
