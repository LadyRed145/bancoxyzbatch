package cl.duoc.bancoxyz.bffmobile.exception;

public class BackendTimeoutException extends RuntimeException {

    public BackendTimeoutException(String operacion, Throwable cause) {
        super("El Bank Backend excedió el tiempo máximo durante: " + operacion, cause);
    }
}
