package cl.duoc.bancoxyz.backend.kafka;

import cl.duoc.bancoxyz.event.RetiroRealizadoEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

/**
 * Publica eventos de retiro en Kafka sin mezclar la mensajería con la lógica
 * de negocio del servicio de cuentas.
 */
@Service
public class RetiroKafkaProducer {

    private static final Logger LOGGER = LoggerFactory.getLogger(RetiroKafkaProducer.class);
    private static final String TOPIC = KafkaTopicConfig.RETIROS_TOPIC;

    private final KafkaTemplate<String, RetiroRealizadoEvent> kafkaTemplate;

    public RetiroKafkaProducer(
            KafkaTemplate<String, RetiroRealizadoEvent> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void publicarRetiro(RetiroRealizadoEvent evento) {
        LOGGER.debug(
                "Publicando retiro Kafka cuentaId={} monto={} saldoFinal={} tipo={}",
                evento.getCuentaId(),
                evento.getMonto(),
                evento.getSaldoFinal(),
                evento.getTipo()
        );

        kafkaTemplate.send(
                TOPIC,
                String.valueOf(evento.getCuentaId()),
                evento
        ).whenComplete((resultado, error) -> {
            if (error != null) {
                LOGGER.error(
                        "ERROR PUBLICANDO EVENTO KAFKA cuentaId={} topic={}",
                        evento.getCuentaId(),
                        TOPIC,
                        error
                );
                return;
            }

            LOGGER.info(
                    "EVENTO KAFKA PUBLICADO CORRECTAMENTE topic={} partition={} offset={} cuentaId={}",
                    resultado.getRecordMetadata().topic(),
                    resultado.getRecordMetadata().partition(),
                    resultado.getRecordMetadata().offset(),
                    evento.getCuentaId()
            );
        });
    }
}
