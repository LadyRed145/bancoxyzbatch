package cl.duoc.bancoxyzbatch.repository;

import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Centralizo las consultas utilizadas durante el procesamiento
 * y reconciliación de las transacciones.
 */
public interface TransaccionProcesadaRepository
        extends JpaRepository<TransaccionProcesada, Long> {

    List<TransaccionProcesada>
    findByActivoTrueOrderByFechaAscIdAsc();

    /**
     * Recupero las transacciones procesadas durante
     * una JobInstance específica en un orden estable.
     */
    List<TransaccionProcesada>
    findByUltimaInstanciaIdOrderByFechaAscIdAsc(
            Long ultimaInstanciaId
    );

    /**
     * Desactivo los registros que no fueron encontrados
     * durante la ejecución actual.
     */
    @Modifying(
            clearAutomatically = true,
            flushAutomatically = true
    )
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
            @Param("jobInstanceId")
            Long jobInstanceId
    );
}
