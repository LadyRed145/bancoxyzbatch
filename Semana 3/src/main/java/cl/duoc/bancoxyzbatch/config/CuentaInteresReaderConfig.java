package cl.duoc.bancoxyzbatch.config;

import cl.duoc.bancoxyzbatch.model.CuentaInteres;
import cl.duoc.bancoxyzbatch.util.CsvValueParser;
import org.springframework.batch.infrastructure.item.file.FlatFileItemReader;
import org.springframework.batch.infrastructure.item.file.builder.FlatFileItemReaderBuilder;
import org.springframework.batch.infrastructure.item.support.SynchronizedItemStreamReader;
import org.springframework.batch.infrastructure.item.support.builder.SynchronizedItemStreamReaderBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

/**
 * Configuro la lectura del CSV utilizado para calcular intereses.
 *
 * Los valores legacy se convierten de forma tolerante.
 * Los campos vacíos o con formatos inválidos se representan como null
 * para permitir que las reglas del ItemProcessor determinen su tratamiento.
 *
 * Mantengo el reader sincronizado para preservar la seguridad de lectura
 * cuando el Step utiliza procesamiento concurrente.
 */
@Configuration
public class CuentaInteresReaderConfig {

    @Bean(name = "cuentaInteresReader")
    public SynchronizedItemStreamReader<CuentaInteres>
    cuentaInteresReader() {

        FlatFileItemReader<CuentaInteres> delegate =
                new FlatFileItemReaderBuilder<CuentaInteres>()
                        .name(
                                "cuentaInteresFlatFileReader"
                        )
                        .resource(
                                new ClassPathResource(
                                        "data/intereses.csv"
                                )
                        )
                        .linesToSkip(1)
                        .delimited()
                        .delimiter(",")
                        .names(
                                "cuenta_id",
                                "nombre",
                                "saldo",
                                "edad",
                                "tipo"
                        )
                        .fieldSetMapper(fieldSet -> {

                            CuentaInteres cuenta =
                                    new CuentaInteres();

                            cuenta.setCuentaId(
                                    CsvValueParser.parseLong(
                                            fieldSet.readString(
                                                    "cuenta_id"
                                            )
                                    )
                            );

                            cuenta.setNombre(
                                    CsvValueParser.parseString(
                                            fieldSet.readString(
                                                    "nombre"
                                            )
                                    )
                            );

                            cuenta.setSaldo(
                                    CsvValueParser.parseBigDecimal(
                                            fieldSet.readString(
                                                    "saldo"
                                            )
                                    )
                            );

                            cuenta.setEdad(
                                    CsvValueParser.parseInteger(
                                            fieldSet.readString(
                                                    "edad"
                                            )
                                    )
                            );

                            cuenta.setTipo(
                                    CsvValueParser.parseString(
                                            fieldSet.readString(
                                                    "tipo"
                                            )
                                    )
                            );

                            return cuenta;
                        })
                        .build();

        /*
         * Mantengo el acceso sincronizado al reader.
         * La estrategia de ejecución del Job se ajustará posteriormente
         * sin modificar la responsabilidad de esta configuración.
         */
        return new SynchronizedItemStreamReaderBuilder<CuentaInteres>()
                .delegate(delegate)
                .build();
    }
}
