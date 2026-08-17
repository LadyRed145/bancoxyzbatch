package cl.duoc.bancoxyzbatch.repository;

import cl.duoc.bancoxyzbatch.model.EstadoCuentaAnual;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

public interface EstadoCuentaAnualRepository
        extends JpaRepository<EstadoCuentaAnual, Long> {

    Optional<EstadoCuentaAnual> findByCuentaIdAndAnio(
            Long cuentaId,
            Integer anio
    );

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query("""
            UPDATE EstadoCuentaAnual e
            SET e.activo = false
            WHERE e.activo = true
              AND (
                    e.ultimaInstanciaId IS NULL
                    OR e.ultimaInstanciaId <> :jobInstanceId
              )
            """)
    int marcarInactivosNoVistos(
            @Param("jobInstanceId") Long jobInstanceId
    );
}
