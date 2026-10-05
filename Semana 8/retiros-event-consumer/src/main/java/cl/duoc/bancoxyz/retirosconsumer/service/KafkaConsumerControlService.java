package cl.duoc.bancoxyz.retirosconsumer.service;

import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.TopicDescription;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.kafka.config.KafkaListenerEndpointRegistry;
import org.springframework.kafka.listener.MessageListenerContainer;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * Encapsula la administración del listener y la consulta de topología Kafka.
 * El controller sólo expone operaciones; el acceso a Spring Kafka permanece
 * concentrado en este servicio.
 */
@Service
public class KafkaConsumerControlService {

    public static final String LISTENER_ID = "retirosListener";
    public static final String TOPIC = "bancoxyz.retiros";
    public static final String GROUP_ID = "bancoxyz-retiros-group";

    private static final long ADMIN_TIMEOUT_SECONDS = 5;

    private final KafkaListenerEndpointRegistry registry;
    private final KafkaConsumerMonitor monitor;
    private final String bootstrapServers;

    public KafkaConsumerControlService(
            KafkaListenerEndpointRegistry registry,
            KafkaConsumerMonitor monitor,
            @Value("${spring.kafka.bootstrap-servers}") String bootstrapServers
    ) {
        this.registry = registry;
        this.monitor = monitor;
        this.bootstrapServers = bootstrapServers;
    }

    public Map<String, Object> pausar() {
        MessageListenerContainer container = listenerContainer();

        if (!container.isPauseRequested()) {
            container.pause();
        }

        return estado();
    }

    public Map<String, Object> reanudar() {
        MessageListenerContainer container = listenerContainer();

        if (container.isPauseRequested()) {
            container.resume();
        }

        return estado();
    }

    public Map<String, Object> estado() {
        MessageListenerContainer container = listenerContainer();

        Map<String, Object> estado = new LinkedHashMap<>();
        estado.put("listenerId", LISTENER_ID);
        estado.put("topic", TOPIC);
        estado.put("groupId", GROUP_ID);
        estado.put("ejecutando", container.isRunning());
        estado.put("pausaSolicitada", container.isPauseRequested());
        estado.put("consumidorPausado", container.isContainerPaused());
        estado.put("estado", resolverEstado(container));
        estado.put("eventosProcesados", monitor.getEventosProcesados());
        estado.put(
                "ultimoEventoProcesado",
                monitor.getUltimoEventoProcesado() == null
                        ? null
                        : monitor.getUltimoEventoProcesado().toString()
        );
        return estado;
    }

    public Map<String, Object> resumen() {
        Map<String, Object> resumen = new LinkedHashMap<>(estado());
        resumen.put("bootstrapServers", bootstrapServers);

        // AdminClient confirma la topología real del cluster, no sólo la configuración esperada.
        try (AdminClient admin = AdminClient.create(Map.of(
                AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG,
                bootstrapServers
        ))) {
            int brokers = admin.describeCluster()
                    .nodes()
                    .get(ADMIN_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                    .size();

            TopicDescription topic = admin.describeTopics(List.of(TOPIC))
                    .allTopicNames()
                    .get(ADMIN_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                    .get(TOPIC);

            int particiones = topic.partitions().size();
            int replicaMin = topic.partitions().stream()
                    .mapToInt(partition -> partition.replicas().size())
                    .min()
                    .orElse(0);

            int replicaMax = topic.partitions().stream()
                    .mapToInt(partition -> partition.replicas().size())
                    .max()
                    .orElse(0);

            resumen.put("clusterDisponible", true);
            resumen.put("brokers", brokers);
            resumen.put("particiones", particiones);
            resumen.put("factorReplicacionMin", replicaMin);
            resumen.put("factorReplicacionMax", replicaMax);
            resumen.put("cumpleTresBrokers", brokers >= 3);
            resumen.put("cumpleTresParticiones", particiones >= 3);
            resumen.put("cumpleReplicacionTres", replicaMin >= 3);
        } catch (Exception exception) {
            // La API sigue entregando estado local aunque la consulta administrativa falle.
            resumen.put("clusterDisponible", false);
            resumen.put("errorConsultaCluster", exception.getClass().getSimpleName());
        }

        return resumen;
    }

    private MessageListenerContainer listenerContainer() {
        MessageListenerContainer container = registry.getListenerContainer(LISTENER_ID);

        if (container == null) {
            throw new ResponseStatusException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "Kafka listener no disponible"
            );
        }

        return container;
    }

    private String resolverEstado(MessageListenerContainer container) {
        if (!container.isRunning()) {
            return "DETENIDO";
        }

        if (container.isContainerPaused()) {
            return "PAUSADO";
        }

        if (container.isPauseRequested()) {
            return "PAUSA_SOLICITADA";
        }

        return "ACTIVO";
    }
}
