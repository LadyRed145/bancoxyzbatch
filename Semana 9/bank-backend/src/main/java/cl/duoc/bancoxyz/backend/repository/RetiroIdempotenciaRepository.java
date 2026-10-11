package cl.duoc.bancoxyz.backend.repository;

import cl.duoc.bancoxyz.backend.entity.RetiroIdempotencia;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;

public interface RetiroIdempotenciaRepository extends JpaRepository<RetiroIdempotencia, UUID> { }
