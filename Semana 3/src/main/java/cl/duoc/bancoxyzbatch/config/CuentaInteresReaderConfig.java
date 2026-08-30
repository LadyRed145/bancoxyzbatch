package cl.duoc.bancoxyzbatch.config;

import cl.duoc.bancoxyzbatch.model.CuentaInteres;
import org.springframework.batch.infrastructure.item.file.FlatFileItemReader;
import org.springframework.batch.infrastructure.item.file.builder.FlatFileItemReaderBuilder;
import org.springframework.batch.infrastructure.item.support.SynchronizedItemStreamReader;
import org.springframework.batch.infrastructure.item.support.builder.SynchronizedItemStreamReaderBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.math.BigDecimal;

/**
 * Configuro la lectura del CSV utilizado para calcular intereses.
 * Sincronizo el reader porque el Step puede ejecutarse en paralelo.
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
                                    Long.valueOf(
                                            fieldSet
                                                    .readString("cuenta_id")
                                                    .trim()
                                    )
                            );

                            cuenta.setNombre(
                                    fieldSet
                                            .readString("nombre")
                                            .trim()
                            );

                            cuenta.setSaldo(
                                    new BigDecimal(
                                            fieldSet
                                                    .readString("saldo")
                                                    .trim()
                                    )
                            );

                            cuenta.setEdad(
                                    Integer.valueOf(
                                            fieldSet
                                                    .readString("edad")
                                                    .trim()
                                    )
                            );

                            cuenta.setTipo(
                                    fieldSet
                                            .readString("tipo")
                                            .trim()
                            );

                            return cuenta;
                        })
                        .build();

        return new SynchronizedItemStreamReaderBuilder<CuentaInteres>()
                .delegate(delegate)
                .build();
    }
}
