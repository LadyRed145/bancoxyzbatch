package cl.duoc.bancoxyz.backend.repository;

import cl.duoc.bancoxyz.backend.entity.TransaccionProcesada;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TransaccionProcesadaRepository
        extends JpaRepository<TransaccionProcesada, Long> {
}