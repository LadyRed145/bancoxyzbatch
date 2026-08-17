package cl.duoc.bancoxyzbatch.repository;

import cl.duoc.bancoxyzbatch.model.CuentaInteresProcesada;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface CuentaInteresProcesadaRepository
        extends JpaRepository<CuentaInteresProcesada, Long> {

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query("""
            UPDATE CuentaInteresProcesada c
            SET c.activo = false
            WHERE c.activo = true
              AND (
                    c.ultimaInstanciaId IS NULL
                    OR c.ultimaInstanciaId <> :jobInstanceId
              )
            """)
    int marcarInactivosNoVistos(
            @Param("jobInstanceId") Long jobInstanceId
    );
}
