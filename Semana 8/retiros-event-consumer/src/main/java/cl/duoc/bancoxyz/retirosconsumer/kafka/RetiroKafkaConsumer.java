package cl.duoc.bancoxyz.retirosconsumer.kafka;

import cl.duoc.bancoxyz.event.RetiroRealizadoEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
public class RetiroKafkaConsumer {

    private static final Logger LOGGER = LoggerFactory.getLogger(RetiroKafkaConsumer.class);

    @KafkaListener(topics = "bancoxyz.retiros", groupId = "bancoxyz-retiros-group")
    public void consumirRetiro(RetiroRealizadoEvent evento) {
        LOGGER.info(
                "EVENTO_KAFKA_CONSUMIDO topic=bancoxyz.retiros cuentaId={} monto={} saldoFinal={} tipo={}",
                evento.getCuentaId(),
                evento.getMonto(),
                evento.getSaldoFinal(),
                evento.getTipo()
        );
    }
}
