package cl.duoc.bancoxyzbatch.config;

import cl.duoc.bancoxyzbatch.model.Transaccion;
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
 * Configuro la lectura del CSV de transacciones.
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
                                    Long.valueOf(
                                            fieldSet
                                                    .readString("id")
                                                    .trim()
                                    )
                            );

                            transaccion.setFecha(
                                    LocalDate.parse(
                                            fieldSet
                                                    .readString("fecha")
                                                    .trim()
                                    )
                            );

                            transaccion.setMonto(
                                    new BigDecimal(
                                            fieldSet
                                                    .readString("monto")
                                                    .trim()
                                    )
                            );

                            transaccion.setTipo(
                                    fieldSet
                                            .readString("tipo")
                                            .trim()
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
