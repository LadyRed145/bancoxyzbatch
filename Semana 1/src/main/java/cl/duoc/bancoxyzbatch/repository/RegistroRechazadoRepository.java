package cl.duoc.bancoxyzbatch.repository;

import cl.duoc.bancoxyzbatch.model.RegistroRechazado;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RegistroRechazadoRepository
        extends JpaRepository<RegistroRechazado, Long> {
}
