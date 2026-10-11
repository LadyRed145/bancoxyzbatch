package cl.duoc.bancoxyz.retirosconsumer.kafka;

import cl.duoc.bancoxyz.event.RetiroRealizadoEvent;
import cl.duoc.bancoxyz.retirosconsumer.service.KafkaConsumerControlService;
import cl.duoc.bancoxyz.retirosconsumer.service.KafkaConsumerMonitor;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.config.KafkaListenerEndpointRegistry;
import org.springframework.kafka.core.ConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.listener.MessageListenerContainer;
import org.springframework.kafka.support.serializer.JacksonJsonDeserializer;
import org.springframework.kafka.support.serializer.JacksonJsonSerializer;
import org.springframework.kafka.test.EmbeddedKafkaBroker;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.kafka.test.utils.ContainerTestUtils;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Prueba Kafka de integracion REAL, pero aislada del Docker Compose de BancoXYZ.
 *
 * El broker KRaft es efimero, usa un puerto aleatorio y se destruye al terminar.
 * Solo se importan el listener y el monitor de produccion; NO se levanta la
 * aplicacion bancaria, Keycloak, Eureka ni PostgreSQL.
 */
@SpringJUnitConfig(classes = RetiroKafkaConsumerEmbeddedTest.ConfiguracionAislada.class)
@EmbeddedKafka(
        partitions = 1,
        topics = KafkaConsumerControlService.TOPIC,
        brokerProperties = "auto.create.topics.enable=false"
)
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class RetiroKafkaConsumerEmbeddedTest {

    @Autowired
    private KafkaListenerEndpointRegistry registry;

    @Autowired
    private KafkaTemplate<String, RetiroRealizadoEvent> productorAislado;

    @Autowired
    private KafkaConsumerMonitor monitor;

    @Test
    void eventoPublicadoEnBrokerAisladoSeDeserializaYProcesaPorListenerReal() throws Exception {
        MessageListenerContainer listener = registry.getListenerContainer(
                KafkaConsumerControlService.LISTENER_ID
        );
        assertNotNull(listener, "Debe existir el listener real retirosListener");
        assertTrue(listener.isRunning(), "El listener debe estar ejecutandose");

        // Se verifica la asignacion antes de producir: no dependemos de carreras de inicio.
        ContainerTestUtils.waitForAssignment(listener, 1);
        assertEquals(0L, monitor.getEventosProcesados(), "El monitor comienza en cero");

        RetiroRealizadoEvent eventoDeLaboratorio = new RetiroRealizadoEvent(
                999_999L,
                new BigDecimal("25.00"),
                new BigDecimal("975.00"),
                "RETIRO_PRUEBA_AISLADA"
        );
        productorAislado.send(KafkaConsumerControlService.TOPIC, "prueba-aislada", eventoDeLaboratorio)
                .get(15, TimeUnit.SECONDS);

        // Espera acotada: no usamos Thread.sleep fijo ni dependemos del ritmo del equipo.
        long limite = System.nanoTime() + Duration.ofSeconds(15).toNanos();
        while (monitor.getEventosProcesados() == 0 && System.nanoTime() < limite) {
            TimeUnit.MILLISECONDS.sleep(50);
        }

        assertEquals(1L, monitor.getEventosProcesados(),
                "El evento debe llegar al listener real exactamente una vez");
        assertNotNull(monitor.getUltimoEventoProcesado(),
                "El listener debe registrar el instante del evento");
    }

    @Configuration(proxyBeanMethods = false)
    @EnableKafka
    @Import({RetiroKafkaConsumer.class, KafkaConsumerMonitor.class})
    static class ConfiguracionAislada {

        @Bean
        ConsumerFactory<String, RetiroRealizadoEvent> consumerFactory(EmbeddedKafkaBroker broker) {
            Map<String, Object> properties = new HashMap<>();
            // UNICAMENTE el broker embebido: nunca localhost:9092 ni kafka-1:19092.
            properties.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, broker.getBrokersAsString());
            properties.put(ConsumerConfig.GROUP_ID_CONFIG, KafkaConsumerControlService.GROUP_ID);
            properties.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
            properties.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
            return new DefaultKafkaConsumerFactory<>(
                    properties,
                    new StringDeserializer(),
                    // Tipo fijo: no necesita leer cabeceras de tipos arbitrarios.
                    new JacksonJsonDeserializer<>(RetiroRealizadoEvent.class, false)
            );
        }

        @Bean
        ConcurrentKafkaListenerContainerFactory<String, RetiroRealizadoEvent> kafkaListenerContainerFactory(
                ConsumerFactory<String, RetiroRealizadoEvent> consumerFactory
        ) {
            ConcurrentKafkaListenerContainerFactory<String, RetiroRealizadoEvent> factory =
                    new ConcurrentKafkaListenerContainerFactory<>();
            factory.setConsumerFactory(consumerFactory);
            return factory;
        }

        @Bean
        KafkaTemplate<String, RetiroRealizadoEvent> productorAislado(EmbeddedKafkaBroker broker) {
            Map<String, Object> properties = new HashMap<>();
            properties.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, broker.getBrokersAsString());
            properties.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
            properties.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JacksonJsonSerializer.class);
            return new KafkaTemplate<>(new DefaultKafkaProducerFactory<>(properties));
        }
    }
}
