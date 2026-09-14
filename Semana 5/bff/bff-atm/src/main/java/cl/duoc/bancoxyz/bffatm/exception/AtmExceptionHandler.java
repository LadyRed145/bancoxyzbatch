package cl.duoc.bancoxyz.bffatm.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.reactive.function.client.WebClientResponseException;

@RestControllerAdvice
public class AtmExceptionHandler {

    @ExceptionHandler(WebClientResponseException.class)
    public ResponseEntity<String> manejarErrorBackend(WebClientResponseException exception) {
        // Los errores de negocio del backend conservan su status para que el ATM no pierda semántica.
        MediaType contentType = exception.getHeaders().getContentType();
        ResponseEntity.BodyBuilder response = ResponseEntity.status(exception.getStatusCode());

        if (contentType != null) {
            response.contentType(contentType);
        }

        return response.body(exception.getResponseBodyAsString());
    }

    @ExceptionHandler(BackendNoDisponibleException.class)
    public ResponseEntity<ProblemDetail> manejarBackendNoDisponible(
            BackendNoDisponibleException exception) {

        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.SERVICE_UNAVAILABLE,
                exception.getMessage()
        );
        problem.setTitle("Bank Backend no disponible");

        return ResponseEntity
                .status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(problem);
    }

    @ExceptionHandler(BackendTimeoutException.class)
    public ResponseEntity<ProblemDetail> manejarTimeoutBackend(
            BackendTimeoutException exception) {

        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.GATEWAY_TIMEOUT,
                exception.getMessage()
        );
        problem.setTitle("Tiempo de espera agotado");

        return ResponseEntity
                .status(HttpStatus.GATEWAY_TIMEOUT)
                .body(problem);
    }
}
