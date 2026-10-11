package cl.duoc.bancoxyz.retirosconsumer.kafka;

import cl.duoc.bancoxyz.event.RetiroRealizadoEvent;
import cl.duoc.bancoxyz.retirosconsumer.service.KafkaConsumerControlService;
import cl.duoc.bancoxyz.retirosconsumer.service.KafkaConsumerMonitor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

/**
 * Listener dedicado a los retiros. El id explícito permite administrar el
 * contenedor en tiempo de ejecución sin acoplar el controller a Spring Kafka.
 */
@Service
public class RetiroKafkaConsumer {

    private static final Logger LOGGER = LoggerFactory.getLogger(RetiroKafkaConsumer.class);

    private final KafkaConsumerMonitor monitor;

    public RetiroKafkaConsumer(KafkaConsumerMonitor monitor) {
        this.monitor = monitor;
    }

    @KafkaListener(
            id = KafkaConsumerControlService.LISTENER_ID,
            topics = KafkaConsumerControlService.TOPIC,
            groupId = KafkaConsumerControlService.GROUP_ID
    )
    public void consumirRetiro(RetiroRealizadoEvent evento) {
        monitor.registrarEventoProcesado();

        // La marca facilita trazabilidad y es consumida por los scripts de evidencia.
        LOGGER.info(
                "EVENTO_KAFKA_CONSUMIDO topic={} cuentaId={} monto={} saldoFinal={} tipo={}",
                KafkaConsumerControlService.TOPIC,
                evento.getCuentaId(),
                evento.getMonto(),
                evento.getSaldoFinal(),
                evento.getTipo()
        );
    }
}
