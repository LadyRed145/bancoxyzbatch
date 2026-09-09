package cl.duoc.bancoxyz.backend.service;

import cl.duoc.bancoxyz.backend.entity.CuentaInteres;
import cl.duoc.bancoxyz.backend.repository.CuentaInteresRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;

import java.util.List;
import java.util.Optional;

@Service
public class CuentaInteresService {

    private final CuentaInteresRepository repository;

    public CuentaInteresService(CuentaInteresRepository repository) {
        this.repository = repository;
    }

    public List<CuentaInteres> obtenerTodas() {
        return repository.findAll();
    }

    public Optional<CuentaInteres> obtenerPorId(Long id) {
        return repository.findById(id);
    }

    @Transactional
    public CuentaInteres retirar(Long cuentaId, BigDecimal monto) {

        if (monto == null || monto.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("El monto debe ser mayor a cero");
        }

        CuentaInteres cuenta = repository.findById(cuentaId)
                .orElseThrow(() -> new RuntimeException("Cuenta no encontrada"));

        if (!Boolean.TRUE.equals(cuenta.getActivo())) {
            throw new IllegalStateException("La cuenta está inactiva");
        }

        if (cuenta.getSaldoFinal().compareTo(monto) < 0) {
            throw new IllegalStateException("Saldo insuficiente");
        }

        cuenta.setSaldoFinal(cuenta.getSaldoFinal().subtract(monto));

        return repository.save(cuenta);
    }
}