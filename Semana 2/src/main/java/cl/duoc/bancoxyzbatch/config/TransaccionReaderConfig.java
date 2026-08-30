package cl.duoc.bancoxyzbatch.config;

import cl.duoc.bancoxyzbatch.model.Transaccion;
import org.springframework.batch.infrastructure.item.file.FlatFileItemReader;
import org.springframework.batch.infrastructure.item.file.builder.FlatFileItemReaderBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.math.BigDecimal;
import java.time.LocalDate;

@Configuration
public class TransaccionReaderConfig {

    @Bean
    public FlatFileItemReader<Transaccion> transaccionReader() {

        return new FlatFileItemReaderBuilder<Transaccion>()
                .name("transaccionReader")
                .resource(new ClassPathResource("data/transacciones.csv"))
                .linesToSkip(1)
                .delimited()
                .delimiter(",")
                .names("id", "fecha", "monto", "tipo")
                .fieldSetMapper(fieldSet -> {

                    Transaccion transaccion = new Transaccion();

                    transaccion.setId(
                            Long.valueOf(fieldSet.readString("id").trim())
                    );

                    transaccion.setFecha(
                            LocalDate.parse(
                                    fieldSet.readString("fecha").trim()
                            )
                    );

                    transaccion.setMonto(
                            new BigDecimal(
                                    fieldSet.readString("monto").trim()
                            )
                    );

                    transaccion.setTipo(
                            fieldSet.readString("tipo").trim()
                    );

                    return transaccion;
                })
                .build();
    }
}
