package cl.duoc.bancoxyz.cuentas.service;
import cl.duoc.bancoxyz.cuentas.entity.CuentaInteres;
import cl.duoc.bancoxyz.cuentas.repository.CuentaInteresRepository;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service
@Transactional(readOnly = true)
public class CuentasConsultaService {
 private final CuentaInteresRepository repository;
 public CuentasConsultaService(CuentaInteresRepository repository) {this.repository = repository;}
 public List<CuentaInteres> obtenerTodas() {return repository.findAll();}
 public Optional<CuentaInteres> obtenerPorId(Long id) {return repository.findById(id);}
}
