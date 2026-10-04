package cl.duoc.bancoxyz.backend.kafka;

import cl.duoc.bancoxyz.event.RetiroRealizadoEvent;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class RetiroKafkaProducer {

    private static final String TOPIC = "bancoxyz.retiros";

    private final KafkaTemplate<String, RetiroRealizadoEvent> kafkaTemplate;

    public RetiroKafkaProducer(
            KafkaTemplate<String, RetiroRealizadoEvent> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void publicarRetiro(RetiroRealizadoEvent evento) {

        System.out.println(">>> ENTRANDO AL PRODUCER KAFKA");
        System.out.println("Cuenta: " + evento.getCuentaId());
        System.out.println("Monto: " + evento.getMonto());
        System.out.println("Saldo final: " + evento.getSaldoFinal());

        kafkaTemplate.send(
                TOPIC,
                String.valueOf(evento.getCuentaId()),
                evento
        ).whenComplete((resultado, error) -> {

            if (error != null) {
                System.err.println("ERROR PUBLICANDO EVENTO KAFKA:");
                error.printStackTrace();
            } else {
                System.out.println("EVENTO KAFKA PUBLICADO CORRECTAMENTE:");
                System.out.println("Topic: " + resultado.getRecordMetadata().topic());
                System.out.println("Partition: " + resultado.getRecordMetadata().partition());
                System.out.println("Offset: " + resultado.getRecordMetadata().offset());
            }
        });
    }
}