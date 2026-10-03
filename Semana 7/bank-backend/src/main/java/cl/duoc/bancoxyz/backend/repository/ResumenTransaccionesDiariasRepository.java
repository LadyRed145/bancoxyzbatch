package cl.duoc.bancoxyz.backend.repository;

import cl.duoc.bancoxyz.backend.entity.ResumenTransaccionesDiarias;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;

public interface ResumenTransaccionesDiariasRepository
        extends JpaRepository<ResumenTransaccionesDiarias, LocalDate> {
}