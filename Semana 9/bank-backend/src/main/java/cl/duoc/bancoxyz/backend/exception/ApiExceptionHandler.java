package cl.duoc.bancoxyz.backend.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(CuentaNoEncontradaException.class)
    public ProblemDetail manejarCuentaNoEncontrada(CuentaNoEncontradaException exception) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                exception.getMessage()
        );
        problem.setTitle("Cuenta no encontrada");
        return problem;
    }

    @ExceptionHandler(CuentaInactivaException.class)
    public ProblemDetail manejarCuentaInactiva(CuentaInactivaException exception) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.CONFLICT,
                exception.getMessage()
        );
        problem.setTitle("Cuenta inactiva");
        return problem;
    }

    @ExceptionHandler(SaldoInsuficienteException.class)
    public ProblemDetail manejarSaldoInsuficiente(SaldoInsuficienteException exception) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.CONFLICT,
                exception.getMessage()
        );
        problem.setTitle("Saldo insuficiente");
        return problem;
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ProblemDetail manejarArgumentoInvalido(IllegalArgumentException exception) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                exception.getMessage()
        );
        problem.setTitle("Solicitud invalida");
        return problem;
    }
}
