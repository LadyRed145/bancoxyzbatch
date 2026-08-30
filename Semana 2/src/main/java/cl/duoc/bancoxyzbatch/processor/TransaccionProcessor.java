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

        /*
          Evidencia del hilo que está procesando
          cada transacción.

          Permite comprobar el procesamiento
          concurrente configurado en Spring Batch.
         */
        System.out.println(
                "[BATCH-PROCESSOR] hilo="
                        + Thread.currentThread().getName()
                        + " | transaccion="
                        + item.getId()
        );

        TransaccionProcesada salida =
                new TransaccionProcesada();

        salida.setId(item.getId());
        salida.setFecha(item.getFecha());
        salida.setMonto(item.getMonto());
        salida.setTipo(normalizarTipo(item.getTipo()));
        salida.setEstado("PROCESADO");
        salida.setObservacion("Transacción válida");

        /*
          Validación del identificador.
         */
        if (item.getId() == null) {

            salida.setEstado("RECHAZADO");

            salida.setObservacion(
                    "La transacción no posee identificador"
            );

            return salida;
        }

        /*
          Validación de fecha.
         */
        if (item.getFecha() == null) {

            salida.setEstado("RECHAZADO");

            salida.setObservacion(
                    "Fecha inexistente o inválida"
            );

            return salida;
        }

        /*
          Validación del monto.
         */
        if (item.getMonto() == null) {

            salida.setEstado("RECHAZADO");

            salida.setObservacion(
                    "Monto inexistente"
            );

            return salida;
        }

        /*
          Una transacción con monto cero
          no es considerada válida.
         */
        if (item.getMonto().compareTo(BigDecimal.ZERO) == 0) {

            salida.setEstado("RECHAZADO");

            salida.setObservacion(
                    "Transacción con monto igual a cero"
            );

            return salida;
        }

        /*
          Normalización y validación del tipo
          de transacción.
         */
        String tipo =
                normalizarTipo(item.getTipo());

        if (!TIPOS_VALIDOS.contains(tipo)) {

            salida.setEstado("RECHAZADO");

            salida.setObservacion(
                    "Tipo de transacción no reconocido: "
                            + item.getTipo()
            );

            return salida;
        }

        /*
          Regla de normalización:

          En transacciones.csv los débitos se expresan
          mayoritariamente mediante montos positivos.

          Si aparece un débito negativo, se normaliza
          utilizando su valor absoluto y se registra
          como una anomalía corregida.
         */
        if ("debito".equals(tipo)
                && item.getMonto().compareTo(BigDecimal.ZERO) < 0) {

            salida.setMonto(
                    item.getMonto().abs()
            );

            salida.setEstado("CORREGIDO");

            salida.setObservacion(
                    "Monto negativo de débito "
                            + "normalizado a valor absoluto"
            );
        }

        return salida;
    }

    /*
      Normaliza el tipo de transacción:

      elimina espacios
      convierte a minúsculas
     */
    private String normalizarTipo(String tipo) {

        if (tipo == null) {
            return "";
        }

        return tipo
                .trim()
                .toLowerCase(Locale.ROOT);
    }
}