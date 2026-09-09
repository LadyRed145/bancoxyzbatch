package cl.duoc.bancoxyz.backend.service;

import cl.duoc.bancoxyz.backend.entity.EstadoCuentaAnual;
import cl.duoc.bancoxyz.backend.repository.EstadoCuentaAnualRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class EstadoCuentaAnualService {

    private final EstadoCuentaAnualRepository repository;

    public EstadoCuentaAnualService(EstadoCuentaAnualRepository repository) {
        this.repository = repository;
    }

    public List<EstadoCuentaAnual> obtenerTodos() {
        return repository.findAll();
    }

    public List<EstadoCuentaAnual> obtenerPorCuenta(Long cuentaId) {
        return repository.findByCuentaId(cuentaId);
    }
}