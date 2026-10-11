package cl.duoc.bancoxyz.shared.resilience;

/** Error de comunicación compartido, sin cambiar los contratos HTTP de cada BFF. */
public class BackendNoDisponibleException extends RuntimeException {

    public BackendNoDisponibleException(String operacion, Throwable cause) {
        super("El Bank Backend no está disponible durante: " + operacion, cause);
    }
}
