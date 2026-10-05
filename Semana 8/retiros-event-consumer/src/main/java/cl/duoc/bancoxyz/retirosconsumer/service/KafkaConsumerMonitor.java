package cl.duoc.bancoxyz.retirosconsumer.service;

import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Mantiene métricas livianas del proceso consumidor para exponer estado sin
 * depender de una base de datos ni bloquear el hilo del listener.
 */
@Component
public class KafkaConsumerMonitor {

    private final AtomicLong eventosProcesados = new AtomicLong();
    private volatile Instant ultimoEventoProcesado;

    public void registrarEventoProcesado() {
        eventosProcesados.incrementAndGet();
        ultimoEventoProcesado = Instant.now();
    }

    public long getEventosProcesados() {
        return eventosProcesados.get();
    }

    public Instant getUltimoEventoProcesado() {
        return ultimoEventoProcesado;
    }
}
