package cl.duoc.bancoxyzbatch.processor;

import cl.duoc.bancoxyzbatch.exception.ReglaNegocioException;
import cl.duoc.bancoxyzbatch.model.MovimientoAnual;
import org.springframework.batch.infrastructure.item.ItemProcessor;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Locale;
import java.util.Set;

@Component
public class MovimientoAnualProcessor
        implements ItemProcessor<MovimientoAnual, MovimientoAnual> {

    private static final Set<String> TIPOS_VALIDOS =
            Set.of("deposito", "retiro", "compra");

    @Override
    public MovimientoAnual process(MovimientoAnual item) {

       /**
        * El procesamiento puede ejecutarse en paralelo mediante un
        * ThreadPoolTaskExecutor con cantidad de hilos configurable.
        * Por este motivo, el orden de procesamiento de los items no es determinista.
        */
        System.out.println(
                "[BATCH-PROCESSOR] hilo="
                        + Thread.currentThread().getName()
                        + " | cuenta="
                        + (item != null
                        ? item.getCuentaId()
                        : "N/A")
        );

        /*
          Validación del objeto.
         */
        if (item == null) {
            throw new ReglaNegocioException(
                    "El movimiento anual es nulo"
            );
        }

        /*
          Validación de la cuenta.
         */
        if (item.getCuentaId() == null) {
            throw new ReglaNegocioException(
                    "El movimiento anual no posee cuenta_id"
            );
        }

        /*
          Validación de fecha.
         */
        if (item.getFecha() == null) {
            throw new ReglaNegocioException(
                    "El movimiento anual no posee una fecha válida"
            );
        }

        /*
          Validación del monto.
         */
        if (item.getMonto() == null) {
            throw new ReglaNegocioException(
                    "El movimiento anual no posee monto"
            );
        }

        /*
          Validación del tipo de transacción.
         */
        if (item.getTransaccion() == null
                || item.getTransaccion().isBlank()) {

            throw new ReglaNegocioException(
                    "El movimiento anual no posee tipo de transacción"
            );
        }

        /*
          Normalización del tipo.
         */
        String tipo = item.getTransaccion()
                .trim()
                .toLowerCase(Locale.ROOT);

        /*
          Validación del tipo permitido.
         */
        if (!TIPOS_VALIDOS.contains(tipo)) {
            throw new ReglaNegocioException(
                    "Tipo de transacción anual no válido: "
                            + item.getTransaccion()
            );
        }

        /*
          El monto cero no corresponde
          a un movimiento válido.
         */
        if (item.getMonto().compareTo(BigDecimal.ZERO) == 0) {
            throw new ReglaNegocioException(
                    "El movimiento anual posee monto igual a cero"
            );
        }

        /*
          Normalización del signo del monto:

          deposito -> positivo
          retiro   -> negativo
          compra   -> negativo
         */
        switch (tipo) {

            case "deposito" ->
                    item.setMonto(
                            item.getMonto().abs()
                    );

            case "retiro", "compra" ->
                    item.setMonto(
                            item.getMonto()
                                    .abs()
                                    .negate()
                    );

            default ->
                    throw new ReglaNegocioException(
                            "Tipo de transacción anual no soportado: "
                                    + tipo
                    );
        }

        /*
         Guarda el tipo ya normalizado.
         */
        item.setTransaccion(tipo);

        /*
          Limpia espacios innecesarios
          de la descripción.
         */
        if (item.getDescripcion() != null) {
            item.setDescripcion(
                    item.getDescripcion().trim()
            );
        }

        return item;
    }
}