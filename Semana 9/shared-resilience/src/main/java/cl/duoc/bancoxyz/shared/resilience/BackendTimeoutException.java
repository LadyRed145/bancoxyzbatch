package cl.duoc.bancoxyz.shared.resilience;

/** Error de comunicación compartido, sin cambiar los contratos HTTP de cada BFF. */
public class BackendTimeoutException extends RuntimeException {

    public BackendTimeoutException(String operacion, Throwable cause) {
        super("El Bank Backend excedió el tiempo máximo durante: " + operacion, cause);
    }
}
