package cl.duoc.bancoxyz.bffmobile.exception;

public class BackendNoDisponibleException extends RuntimeException {

    public BackendNoDisponibleException(String operacion, Throwable cause) {
        super("El Bank Backend no está disponible durante: " + operacion, cause);
    }
}
