package cl.duoc.bancoxyzbatch.processor;

import cl.duoc.bancoxyzbatch.exception.ReglaNegocioException;
import cl.duoc.bancoxyzbatch.model.MovimientoAnual;
import org.springframework.batch.infrastructure.item.ItemProcessor;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.text.Normalizer;
import java.util.Locale;
import java.util.Set;

@Component
public class MovimientoAnualProcessor
        implements ItemProcessor<MovimientoAnual, MovimientoAnual> {

    private static final Set<String> TIPOS_VALIDOS =
            Set.of(
                    "deposito",
                    "retiro",
                    "compra"
            );

    @Override
    public MovimientoAnual process(
            MovimientoAnual item
    ) {

        /*
         * Primero valido el objeto antes de acceder
         * a cualquiera de sus propiedades.
         */
        if (item == null) {

            throw new ReglaNegocioException(
                    "El movimiento anual es nulo"
            );
        }

        /*
         * Evidencia del hilo que procesa cada movimiento.
         *
         * Esto permite demostrar posteriormente el
         * procesamiento concurrente configurado.
         */
        System.out.println(
                "[BATCH-PROCESSOR] hilo="
                        + Thread.currentThread().getName()
                        + " | cuenta="
                        + item.getCuentaId()
        );

        validarCamposObligatorios(
                item
        );

        /*
         * Normalizo el tipo de movimiento.
         *
         * Ejemplos:
         *
         * deposito  -> deposito
         * depósito  -> deposito
         * DEPÓSITO  -> deposito
         * Retiro    -> retiro
         */
        String tipoNormalizado =
                normalizarTipo(
                        item.getTransaccion()
                );

        validarTipo(
                tipoNormalizado,
                item.getTransaccion()
        );

        /*
         * El signo final del monto se determina por
         * el tipo del movimiento y no por el signo
         * recibido desde el sistema legacy.
         *
         * deposito -> positivo
         * retiro   -> negativo
         * compra   -> negativo
         */
        BigDecimal montoNormalizado =
                normalizarMonto(
                        item.getMonto(),
                        tipoNormalizado
                );

        item.setTransaccion(
                tipoNormalizado
        );

        item.setMonto(
                montoNormalizado
        );

        /*
         * El Reader ya limpia cadenas vacías mediante
         * CsvValueParser, pero mantengo esta normalización
         * defensiva para conservar una salida consistente.
         */
        if (item.getDescripcion() != null) {

            String descripcion =
                    item.getDescripcion().trim();

            item.setDescripcion(
                    descripcion.isEmpty()
                            ? null
                            : descripcion
            );
        }

        return item;
    }

    /**
     * Valida los campos indispensables para consolidar
     * un movimiento dentro del estado de cuenta anual.
     */
    private void validarCamposObligatorios(
            MovimientoAnual item
    ) {

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

        if (item.getMonto()
                .compareTo(BigDecimal.ZERO) == 0) {

            throw new ReglaNegocioException(
                    "El movimiento anual posee monto igual a cero"
            );
        }

        if (item.getTransaccion() == null
                || item.getTransaccion().isBlank()) {

            throw new ReglaNegocioException(
                    "El movimiento anual no posee tipo de transacción"
            );
        }
    }

    /**
     * Comprueba que el movimiento pertenezca a uno
     * de los tipos soportados por el proceso anual.
     */
    private void validarTipo(
            String tipoNormalizado,
            String tipoOriginal
    ) {

        if (!TIPOS_VALIDOS.contains(
                tipoNormalizado
        )) {

            throw new ReglaNegocioException(
                    "Tipo de transacción anual no válido: "
                            + tipoOriginal
            );
        }
    }

    /**
     * Normaliza el signo del monto según la naturaleza
     * del movimiento.
     */
    private BigDecimal normalizarMonto(
            BigDecimal monto,
            String tipo
    ) {

        BigDecimal magnitud =
                monto.abs();

        return switch (tipo) {

            case "deposito" ->
                    magnitud;

            case "retiro", "compra" ->
                    magnitud.negate();

            default ->
                    throw new ReglaNegocioException(
                            "Tipo de transacción anual no soportado: "
                                    + tipo
                    );
        };
    }

    /**
     * Normaliza el nombre del tipo de movimiento.
     *
     * Se eliminan:
     *
     * - espacios laterales;
     * - diferencias entre mayúsculas/minúsculas;
     * - tildes y signos diacríticos.
     *
     * Ejemplo:
     *
     * "Depósito" -> "deposito"
     */
    private String normalizarTipo(
            String tipo
    ) {

        if (tipo == null) {
            return "";
        }

        String minusculas =
                tipo.trim()
                        .toLowerCase(
                                Locale.ROOT
                        );

        String normalizado =
                Normalizer.normalize(
                        minusculas,
                        Normalizer.Form.NFD
                );

        return normalizado
                .replaceAll(
                        "\\p{M}",
                        ""
                );
    }
}
