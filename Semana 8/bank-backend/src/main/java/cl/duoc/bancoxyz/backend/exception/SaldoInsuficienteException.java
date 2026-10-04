package cl.duoc.bancoxyz.backend.exception;

public class SaldoInsuficienteException extends RuntimeException {

    public SaldoInsuficienteException(Long cuentaId) {
        super("Saldo insuficiente en la cuenta " + cuentaId);
    }
}
