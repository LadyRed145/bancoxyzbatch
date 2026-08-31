package cl.duoc.bancoxyzbatch.processor;

import cl.duoc.bancoxyzbatch.exception.ReglaNegocioException;
import cl.duoc.bancoxyzbatch.model.Transaccion;
import cl.duoc.bancoxyzbatch.model.TransaccionProcesada;
import org.springframework.batch.infrastructure.item.ItemProcessor;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Locale;
import java.util.Set;

@Component
public class TransaccionProcessor
        implements ItemProcessor<Transaccion, TransaccionProcesada> {

    private static final Set<String> TIPOS_VALIDOS =
            Set.of(
                    "debito",
                    "credito"
            );

    @Override
    public TransaccionProcesada process(
            Transaccion item
    ) {

        /*
         * Protección defensiva.
         *
         * Spring Batch normalmente no entrega un item null
         * al Processor, pero dejo la validación para evitar
         * comportamientos inesperados.
         */
        if (item == null) {

            throw new ReglaNegocioException(
                    "La transacción recibida es nula"
            );
        }

        /*
         * Evidencia del hilo que procesa cada transacción.
         *
         * Permite demostrar posteriormente el procesamiento
         * concurrente configurado en Spring Batch.
         */
        System.out.println(
                "[BATCH-PROCESSOR] hilo="
                        + Thread.currentThread().getName()
                        + " | transaccion="
                        + item.getId()
        );

        /*
         * Primero valido los campos obligatorios.
         *
         * Los Readers ya convierten valores mal formados
         * o imposibles a null, por lo que desde este punto
         * corresponde aplicar las reglas de negocio.
         */
        validarCamposObligatorios(
                item
        );

        /*
         * Normalizo el tipo antes de validarlo.
         */
        String tipo =
                normalizarTipo(
                        item.getTipo()
                );

        validarTipo(
                tipo,
                item.getTipo()
        );

        /*
         * Los montos financieros se almacenan utilizando
         * magnitud positiva.
         *
         * La dirección de la operación está determinada
         * por el tipo:
         *
         * credito
         * debito
         *
         * Por ello, cualquier monto negativo válido se
         * normaliza utilizando su valor absoluto.
         */
        BigDecimal montoNormalizado =
                normalizarMonto(
                        item.getMonto()
                );

        TransaccionProcesada salida =
                new TransaccionProcesada();

        salida.setId(
                item.getId()
        );

        salida.setFecha(
                item.getFecha()
        );

        salida.setMonto(
                montoNormalizado
        );

        salida.setTipo(
                tipo
        );

        /*
         * Si el monto original era negativo, el dato era
         * recuperable y fue corregido.
         *
         * Esto aplica tanto para créditos como para débitos.
         */
        if (item.getMonto()
                .compareTo(BigDecimal.ZERO) < 0) {

            salida.setEstado(
                    "CORREGIDO"
            );

            salida.setObservacion(
                    "Monto negativo de "
                            + tipo
                            + " normalizado a valor absoluto"
            );

        } else {

            salida.setEstado(
                    "PROCESADO"
            );

            salida.setObservacion(
                    "Transacción válida"
            );
        }

        return salida;
    }

    /**
     * Valido los campos mínimos necesarios para que una
     * transacción pueda persistirse y participar posteriormente
     * en los cálculos financieros.
     */
    private void validarCamposObligatorios(
            Transaccion item
    ) {

        if (item.getId() == null) {

            throw new ReglaNegocioException(
                    "La transacción no posee identificador"
            );
        }

        if (item.getFecha() == null) {

            throw new ReglaNegocioException(
                    "Fecha inexistente o inválida"
            );
        }

        if (item.getMonto() == null) {

            throw new ReglaNegocioException(
                    "Monto inexistente o inválido"
            );
        }

        /*
         * Una transacción de monto cero no representa
         * movimiento financiero alguno.
         */
        if (item.getMonto()
                .compareTo(BigDecimal.ZERO) == 0) {

            throw new ReglaNegocioException(
                    "Transacción con monto igual a cero"
            );
        }
    }

    /**
     * Valido que el tipo pertenezca al conjunto permitido
     * por el proceso de transacciones.
     */
    private void validarTipo(
            String tipoNormalizado,
            String tipoOriginal
    ) {

        if (!TIPOS_VALIDOS.contains(
                tipoNormalizado
        )) {

            throw new ReglaNegocioException(
                    "Tipo de transacción no reconocido: "
                            + tipoOriginal
            );
        }
    }

    /**
     * Normalizo la magnitud del monto.
     *
     * El signo no representa la dirección de la operación;
     * esa responsabilidad corresponde al tipo de transacción.
     */
    private BigDecimal normalizarMonto(
            BigDecimal monto
    ) {

        return monto.abs();
    }

    /**
     * Normalizo el tipo de transacción:
     *
     * - elimino espacios laterales;
     * - convierto a minúsculas.
     */
    private String normalizarTipo(
            String tipo
    ) {

        if (tipo == null) {
            return "";
        }

        return tipo
                .trim()
                .toLowerCase(
                        Locale.ROOT
                );
    }
}
