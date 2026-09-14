package cl.duoc.bancoxyz.backend.exception;

public class CuentaNoEncontradaException extends RuntimeException {

    public CuentaNoEncontradaException(Long cuentaId) {
        super("No existe la cuenta con ID " + cuentaId);
    }
}
