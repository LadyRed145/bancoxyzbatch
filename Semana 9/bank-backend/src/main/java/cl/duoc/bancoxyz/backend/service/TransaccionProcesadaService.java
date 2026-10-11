package cl.duoc.bancoxyz.backend.service;

import cl.duoc.bancoxyz.backend.entity.TransaccionProcesada;
import cl.duoc.bancoxyz.backend.repository.TransaccionProcesadaRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class TransaccionProcesadaService {

    private final TransaccionProcesadaRepository repository;

    public TransaccionProcesadaService(
            TransaccionProcesadaRepository repository) {
        this.repository = repository;
    }

    public List<TransaccionProcesada> obtenerTodas() {
        return repository.findAll();
    }

    public Optional<TransaccionProcesada> obtenerPorId(Long id) {
        return repository.findById(id);
    }
}