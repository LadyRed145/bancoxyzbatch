package cl.duoc.bancoxyz.backend.service;

import cl.duoc.bancoxyz.backend.entity.ResumenTransaccionesDiarias;
import cl.duoc.bancoxyz.backend.repository.ResumenTransaccionesDiariasRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
public class ResumenTransaccionesService {

    private final ResumenTransaccionesDiariasRepository repository;

    public ResumenTransaccionesService(
            ResumenTransaccionesDiariasRepository repository) {
        this.repository = repository;
    }

    public List<ResumenTransaccionesDiarias> obtenerTodos() {
        return repository.findAll();
    }

    public ResumenTransaccionesDiarias obtenerPorFecha(LocalDate fecha) {
        return repository.findById(fecha).orElse(null);
    }
}