package cl.duoc.bancoxyzbatch.repository;

import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface TransaccionProcesadaRepository
        extends JpaRepository<TransaccionProcesada, Long> {

    List<TransaccionProcesada>
    findByActivoTrueOrderByFechaAscIdAsc();

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query("""
            UPDATE TransaccionProcesada t
            SET t.activo = false
            WHERE t.activo = true
              AND (
                    t.ultimaInstanciaId IS NULL
                    OR t.ultimaInstanciaId <> :jobInstanceId
              )
            """)
    int marcarInactivosNoVistos(
            @Param("jobInstanceId") Long jobInstanceId
    );
}
