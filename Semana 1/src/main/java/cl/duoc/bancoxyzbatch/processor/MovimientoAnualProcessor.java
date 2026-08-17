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

        if (item == null) {
            throw new ReglaNegocioException(
                    "El movimiento anual es nulo"
            );
        }

        if (item.getCuentaId() == null) {
            throw new ReglaNegocioException(
                    "El movimiento anual no posee cuenta_id"
            );
        }

        if (item.getFecha() == null) {
            throw new ReglaNegocioException(
                    "El movimiento anual no posee una fecha válida"
            );
        }

        if (item.getMonto() == null) {
            throw new ReglaNegocioException(
                    "El movimiento anual no posee monto"
            );
        }

        if (item.getTransaccion() == null
                || item.getTransaccion().isBlank()) {

            throw new ReglaNegocioException(
                    "El movimiento anual no posee tipo de transacción"
            );
        }

        String tipo = item.getTransaccion()
                .trim()
                .toLowerCase(Locale.ROOT);

        if (!TIPOS_VALIDOS.contains(tipo)) {
            throw new ReglaNegocioException(
                    "Tipo de transacción anual no válido: "
                            + item.getTransaccion()
            );
        }

        if (item.getMonto().compareTo(BigDecimal.ZERO) == 0) {
            throw new ReglaNegocioException(
                    "El movimiento anual posee monto igual a cero"
            );
        }

        switch (tipo) {

            case "deposito" ->
                    item.setMonto(item.getMonto().abs());

            case "retiro", "compra" ->
                    item.setMonto(item.getMonto().abs().negate());

            default ->
                    throw new ReglaNegocioException(
                            "Tipo de transacción anual no soportado: "
                                    + tipo
                    );
        }

        item.setTransaccion(tipo);

        if (item.getDescripcion() != null) {
            item.setDescripcion(
                    item.getDescripcion().trim()
            );
        }

        return item;
    }
}
