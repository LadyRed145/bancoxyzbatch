package cl.duoc.bancoxyz.backend.service;

import cl.duoc.bancoxyz.backend.entity.CuentaInteres;
import cl.duoc.bancoxyz.backend.exception.CuentaInactivaException;
import cl.duoc.bancoxyz.backend.exception.CuentaNoEncontradaException;
import cl.duoc.bancoxyz.backend.exception.SaldoInsuficienteException;
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
                .orElseThrow(() -> new CuentaNoEncontradaException(cuentaId));

        if (!Boolean.TRUE.equals(cuenta.getActivo())) {
            throw new CuentaInactivaException(cuentaId);
        }

        if (cuenta.getSaldoFinal().compareTo(monto) < 0) {
            throw new SaldoInsuficienteException(cuentaId);
        }

        cuenta.setSaldoFinal(cuenta.getSaldoFinal().subtract(monto));
        return repository.save(cuenta);
    }
}
