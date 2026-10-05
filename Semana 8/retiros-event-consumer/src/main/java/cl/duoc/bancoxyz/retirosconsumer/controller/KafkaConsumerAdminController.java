package cl.duoc.bancoxyz.retirosconsumer.controller;

import cl.duoc.bancoxyz.retirosconsumer.service.KafkaConsumerControlService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * API administrativa mínima para observar, pausar y reanudar el listener.
 * El acceso está protegido por Spring Security en SecurityConfig.
 */
@RestController
@RequestMapping("/api/kafka/consumer")
public class KafkaConsumerAdminController {

    private final KafkaConsumerControlService controlService;

    public KafkaConsumerAdminController(KafkaConsumerControlService controlService) {
        this.controlService = controlService;
    }

    @PostMapping("/pausar")
    public ResponseEntity<Map<String, Object>> pausar() {
        return ResponseEntity.ok(controlService.pausar());
    }

    @PostMapping("/reanudar")
    public ResponseEntity<Map<String, Object>> reanudar() {
        return ResponseEntity.ok(controlService.reanudar());
    }

    @GetMapping("/estado")
    public ResponseEntity<Map<String, Object>> estado() {
        return ResponseEntity.ok(controlService.estado());
    }

    @GetMapping("/resumen")
    public ResponseEntity<Map<String, Object>> resumen() {
        return ResponseEntity.ok(controlService.resumen());
    }
}
