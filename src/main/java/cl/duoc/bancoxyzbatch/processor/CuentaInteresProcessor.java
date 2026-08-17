package cl.duoc.bancoxyzbatch.processor;

import cl.duoc.bancoxyzbatch.model.CuentaInteres;
import cl.duoc.bancoxyzbatch.model.CuentaInteresProcesada;
import org.springframework.batch.infrastructure.item.ItemProcessor;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Locale;

@Component
public class CuentaInteresProcessor
        implements ItemProcessor<CuentaInteres, CuentaInteresProcesada> {

    private static final BigDecimal TASA_AHORRO =
            new BigDecimal("0.0100");

    private static final BigDecimal TASA_PRESTAMO =
            new BigDecimal("0.0200");

    @Override
    public CuentaInteresProcesada process(CuentaInteres item) {

        CuentaInteresProcesada salida =
                new CuentaInteresProcesada();

        salida.setCuentaId(item.getCuentaId());
        salida.setNombre(
                item.getNombre() != null
                        ? item.getNombre().trim()
                        : ""
        );
        salida.setSaldoInicial(
                item.getSaldo() != null
                        ? item.getSaldo()
                        : BigDecimal.ZERO
        );
        salida.setTipo(normalizarTipo(item.getTipo()));

        salida.setTasaInteres(BigDecimal.ZERO);
        salida.setInteresCalculado(BigDecimal.ZERO);
        salida.setSaldoFinal(
                item.getSaldo() != null
                        ? item.getSaldo()
                        : BigDecimal.ZERO
        );

        salida.setEstado("PROCESADO");
        salida.setObservacion(
                "Cuenta válida para cálculo de intereses"
        );

        if (item.getCuentaId() == null) {
            salida.setEstado("RECHAZADO");
            salida.setObservacion(
                    "La cuenta no posee identificador"
            );
            return salida;
        }

        if (item.getNombre() == null
                || item.getNombre().isBlank()) {

            salida.setEstado("RECHAZADO");
            salida.setObservacion(
                    "La cuenta no posee nombre de titular"
            );
            return salida;
        }

        if (item.getSaldo() == null) {
            salida.setEstado("RECHAZADO");
            salida.setObservacion(
                    "La cuenta no posee saldo"
            );
            return salida;
        }

        if (item.getSaldo().compareTo(BigDecimal.ZERO) < 0) {
            salida.setEstado("RECHAZADO");
            salida.setObservacion(
                    "El saldo inicial no puede ser negativo"
            );
            return salida;
        }

        String tipo = normalizarTipo(item.getTipo());

        if (item.getSaldo().compareTo(BigDecimal.ZERO) == 0) {
            salida.setEstado("SIN_INTERES");
            salida.setObservacion(
                    "Saldo igual a cero: no genera interés en el período"
            );
            return salida;
        }

        BigDecimal tasa;

        switch (tipo) {

            case "ahorro" -> {
                tasa = TASA_AHORRO;
                salida.setObservacion(
                        "Interés mensual calculado con tasa de ahorro del 1%"
                );
            }

            case "prestamo" -> {
                tasa = TASA_PRESTAMO;
                salida.setObservacion(
                        "Interés mensual calculado con tasa de préstamo del 2%"
                );
            }

            default -> {
                salida.setEstado("RECHAZADO");
                salida.setObservacion(
                        "Tipo de cuenta no soportado para cálculo de intereses: "
                                + item.getTipo()
                );
                return salida;
            }
        }

        BigDecimal interes = item.getSaldo()
                .multiply(tasa)
                .setScale(2, RoundingMode.HALF_UP);

        BigDecimal saldoFinal = item.getSaldo()
                .add(interes)
                .setScale(2, RoundingMode.HALF_UP);

        salida.setTasaInteres(tasa);
        salida.setInteresCalculado(interes);
        salida.setSaldoFinal(saldoFinal);

        return salida;
    }

    private String normalizarTipo(String tipo) {

        if (tipo == null) {
            return "";
        }

        return tipo.trim().toLowerCase(Locale.ROOT);
    }
}
