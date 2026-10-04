package cl.duoc.bancoxyz.backend.kafka;

import cl.duoc.bancoxyz.event.RetiroRealizadoEvent;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
public class RetiroKafkaConsumer {

    @KafkaListener(
            topics = "bancoxyz.retiros",
            groupId = "bancoxyz-retiros-group"
    )
    public void consumirRetiro(RetiroRealizadoEvent evento) {

        System.out.println("========================================");
        System.out.println("EVENTO KAFKA RECIBIDO");
        System.out.println("Cuenta: " + evento.getCuentaId());
        System.out.println("Monto: " + evento.getMonto());
        System.out.println("Saldo final: " + evento.getSaldoFinal());
        System.out.println("Tipo: " + evento.getTipo());
        System.out.println("========================================");
    }
}