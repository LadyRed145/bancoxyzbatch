package cl.duoc.bancoxyz.backend.repository;

import cl.duoc.bancoxyz.backend.entity.EstadoCuentaAnual;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface EstadoCuentaAnualRepository
        extends JpaRepository<EstadoCuentaAnual, Long> {

    List<EstadoCuentaAnual> findByCuentaId(Long cuentaId);
}