package cl.duoc.bancoxyz.backend.repository;

import cl.duoc.bancoxyz.backend.entity.CuentaInteres;
import org.springframework.data.jpa.repository.JpaRepository;


import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

public interface CuentaInteresRepository extends JpaRepository<CuentaInteres, Long> {

    /**
     * Bloqueo transaccional para impedir lecturas
     * concurrentes del mismo saldo antes del retiro.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from CuentaInteres c where c.cuentaId = :id")
    Optional<CuentaInteres> findByIdForUpdate(@Param("id") Long id);


}