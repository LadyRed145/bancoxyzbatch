package cl.duoc.bancoxyz.backend.exception;

public class CuentaInactivaException extends RuntimeException {

    public CuentaInactivaException(Long cuentaId) {
        super("La cuenta " + cuentaId + " se encuentra inactiva");
    }
}
