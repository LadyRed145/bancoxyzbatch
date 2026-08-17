package cl.duoc.bancoxyzbatch.processor;

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
            Set.of("debito", "credito");

    @Override
    public TransaccionProcesada process(Transaccion item) {

        TransaccionProcesada salida = new TransaccionProcesada();

        salida.setId(item.getId());
        salida.setFecha(item.getFecha());
        salida.setMonto(item.getMonto());
        salida.setTipo(normalizarTipo(item.getTipo()));
        salida.setEstado("PROCESADO");
        salida.setObservacion("Transacción válida");

        if (item.getId() == null) {
            salida.setEstado("RECHAZADO");
            salida.setObservacion("La transacción no posee identificador");
            return salida;
        }

        if (item.getFecha() == null) {
            salida.setEstado("RECHAZADO");
            salida.setObservacion("Fecha inexistente o inválida");
            return salida;
        }

        if (item.getMonto() == null) {
            salida.setEstado("RECHAZADO");
            salida.setObservacion("Monto inexistente");
            return salida;
        }

        if (item.getMonto().compareTo(BigDecimal.ZERO) == 0) {
            salida.setEstado("RECHAZADO");
            salida.setObservacion("Transacción con monto igual a cero");
            return salida;
        }

        String tipo = normalizarTipo(item.getTipo());

        if (!TIPOS_VALIDOS.contains(tipo)) {
            salida.setEstado("RECHAZADO");
            salida.setObservacion(
                    "Tipo de transacción no reconocido: " + item.getTipo()
            );
            return salida;
        }

        /*
         * Regla de normalización:
         * En transacciones.csv los débitos se expresan mayoritariamente
         * mediante montos positivos. Si aparece un débito negativo,
         * se normaliza utilizando su valor absoluto y queda registrado
         * como anomalía corregida.
         */
        if ("debito".equals(tipo)
                && item.getMonto().compareTo(BigDecimal.ZERO) < 0) {

            salida.setMonto(item.getMonto().abs());
            salida.setEstado("CORREGIDO");
            salida.setObservacion(
                    "Monto negativo de débito normalizado a valor absoluto"
            );
        }

        return salida;
    }

    private String normalizarTipo(String tipo) {
        if (tipo == null) {
            return "";
        }

        return tipo.trim().toLowerCase(Locale.ROOT);
    }
}
