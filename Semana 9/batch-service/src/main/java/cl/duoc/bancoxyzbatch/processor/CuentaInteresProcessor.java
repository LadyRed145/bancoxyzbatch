package cl.duoc.bancoxyzbatch.processor;

import cl.duoc.bancoxyzbatch.exception.ReglaNegocioException;
import cl.duoc.bancoxyzbatch.model.CuentaInteres;
import cl.duoc.bancoxyzbatch.model.CuentaInteresProcesada;
import org.springframework.batch.infrastructure.item.ItemProcessor;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Locale;
import java.util.Set;

@Component
public class CuentaInteresProcessor
        implements ItemProcessor<CuentaInteres, CuentaInteresProcesada> {

    private static final BigDecimal TASA_AHORRO =
            new BigDecimal("0.0100");

    private static final BigDecimal TASA_PRESTAMO =
            new BigDecimal("0.0200");

    private static final Set<String> TIPOS_VALIDOS =
            Set.of(
                    "ahorro",
                    "prestamo"
            );

    @Override
    public CuentaInteresProcesada process(
            CuentaInteres item
    ) {

        /*
         * Protección defensiva.
         */
        if (item == null) {

            throw new ReglaNegocioException(
                    "La cuenta recibida es nula"
            );
        }

        System.out.println(
                "[BATCH-PROCESSOR] hilo="
                        + Thread.currentThread().getName()
                        + " | cuenta="
                        + item.getCuentaId()
        );

        /*
         * Primero valido los datos obligatorios.
         *
         * El Reader transforma valores imposibles o vacíos
         * a null, por lo que corresponde al Processor
         * decidir si pueden continuar.
         */
        validarCamposObligatorios(
                item
        );

        String tipo =
                normalizarTipo(
                        item.getTipo()
                );

        validarTipo(
                tipo,
                item.getTipo()
        );

        /*
         * La edad no interviene en la regla de cálculo de
         * intereses y tampoco forma parte de la entidad
         * CuentaInteresProcesada.
         *
         * Por ello, una edad nula no invalida la cuenta.
         */

        CuentaInteresProcesada salida =
                new CuentaInteresProcesada();

        salida.setCuentaId(
                item.getCuentaId()
        );

        salida.setNombre(
                item.getNombre().trim()
        );

        salida.setSaldoInicial(
                item.getSaldo()
        );

        salida.setTipo(
                tipo
        );

        salida.setTasaInteres(
                BigDecimal.ZERO
        );

        salida.setInteresCalculado(
                BigDecimal.ZERO
        );

        salida.setSaldoFinal(
                item.getSaldo()
                        .setScale(
                                2,
                                RoundingMode.HALF_UP
                        )
        );

        salida.setEstado(
                "PROCESADO"
        );

        salida.setObservacion(
                "Cuenta válida para cálculo de intereses"
        );

        /*
         * Un saldo cero es válido, pero no genera interés.
         */
        if (item.getSaldo()
                .compareTo(BigDecimal.ZERO) == 0) {

            salida.setEstado(
                    "SIN_INTERES"
            );

            salida.setObservacion(
                    "Saldo igual a cero: no genera interés en el período"
            );

            return salida;
        }

        BigDecimal tasa =
                obtenerTasa(
                        tipo
                );

        BigDecimal interes =
                item.getSaldo()
                        .multiply(tasa)
                        .setScale(
                                2,
                                RoundingMode.HALF_UP
                        );

        BigDecimal saldoFinal =
                item.getSaldo()
                        .add(interes)
                        .setScale(
                                2,
                                RoundingMode.HALF_UP
                        );

        salida.setTasaInteres(
                tasa
        );

        salida.setInteresCalculado(
                interes
        );

        salida.setSaldoFinal(
                saldoFinal
        );

        if ("ahorro".equals(tipo)) {

            salida.setObservacion(
                    "Interés mensual calculado con tasa de ahorro del 1%"
            );

        } else {

            salida.setObservacion(
                    "Interés mensual calculado con tasa de préstamo del 2%"
            );
        }

        return salida;
    }

    /**
     * Valida los campos mínimos necesarios para procesar
     * una cuenta bancaria.
     */
    private void validarCamposObligatorios(
            CuentaInteres item
    ) {

        if (item.getCuentaId() == null) {

            throw new ReglaNegocioException(
                    "La cuenta no posee identificador"
            );
        }

        if (item.getNombre() == null
                || item.getNombre().isBlank()) {

            throw new ReglaNegocioException(
                    "La cuenta no posee nombre de titular"
            );
        }

        if (item.getSaldo() == null) {

            throw new ReglaNegocioException(
                    "La cuenta no posee saldo"
            );
        }

        if (item.getSaldo()
                .compareTo(BigDecimal.ZERO) < 0) {

            throw new ReglaNegocioException(
                    "El saldo inicial no puede ser negativo"
            );
        }
    }

    /**
     * Valida el tipo de cuenta.
     *
     * Para este proceso solo se consideran:
     *
     * ahorro
     * prestamo
     */
    private void validarTipo(
            String tipoNormalizado,
            String tipoOriginal
    ) {

        if (!TIPOS_VALIDOS.contains(
                tipoNormalizado
        )) {

            throw new ReglaNegocioException(
                    "Tipo de cuenta no soportado para cálculo de intereses: "
                            + tipoOriginal
            );
        }
    }

    /**
     * Obtiene la tasa correspondiente al tipo de cuenta.
     */
    private BigDecimal obtenerTasa(
            String tipo
    ) {

        return switch (tipo) {

            case "ahorro" ->
                    TASA_AHORRO;

            case "prestamo" ->
                    TASA_PRESTAMO;

            default ->
                    throw new ReglaNegocioException(
                            "No existe una tasa configurada para el tipo: "
                                    + tipo
                    );
        };
    }

    /**
     * Normaliza el tipo de cuenta:
     *
     * - elimina espacios laterales;
     * - convierte a minúsculas.
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