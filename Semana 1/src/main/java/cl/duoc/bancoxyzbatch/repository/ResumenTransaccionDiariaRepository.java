
package cl.duoc.bancoxyzbatch.repository;

import cl.duoc.bancoxyzbatch.model.ResumenTransaccionDiaria;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;

public interface ResumenTransaccionDiariaRepository
        extends JpaRepository<ResumenTransaccionDiaria, LocalDate> {
}