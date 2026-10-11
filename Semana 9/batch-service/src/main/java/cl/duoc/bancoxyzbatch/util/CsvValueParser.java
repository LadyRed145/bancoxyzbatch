package cl.duoc.bancoxyzbatch.util;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.format.ResolverStyle;
import java.util.List;

/**
 * Utilidad para convertir valores provenientes de los archivos CSV legacy.
 *
 * El objetivo es evitar que un dato vacío, mal formado o con un formato de
 * fecha alternativo detenga la lectura completa del archivo.
 *
 * Los valores que no pueden convertirse de forma segura se devuelven como
 * null para que las reglas de negocio implementadas en los ItemProcessor
 * decidan si deben rechazarse, corregirse o manejarse.
 */
public final class CsvValueParser {

    /*
     * Formatos de fecha encontrados en los archivos legacy.
     *
     * Ejemplos:
     *
     * 2024-06-30
     * 03-04-2024
     * 04/05/2024
     * 2024/10/15
     */
    private static final List<DateTimeFormatter> FORMATOS_FECHA =
            List.of(

                    DateTimeFormatter.ISO_LOCAL_DATE,

                    DateTimeFormatter
                            .ofPattern("dd-MM-uuuu")
                            .withResolverStyle(
                                    ResolverStyle.STRICT
                            ),

                    DateTimeFormatter
                            .ofPattern("dd/MM/uuuu")
                            .withResolverStyle(
                                    ResolverStyle.STRICT
                            ),

                    DateTimeFormatter
                            .ofPattern("uuuu/MM/dd")
                            .withResolverStyle(
                                    ResolverStyle.STRICT
                            )
            );

    /*
     * Clase utilitaria.
     * No debe ser instanciada.
     */
    private CsvValueParser() {
    }

    /**
     * Limpia espacios innecesarios.
     *
     * Si el valor es nulo o contiene únicamente espacios,
     * retorna null.
     */
    public static String parseString(String value) {

        if (value == null) {
            return null;
        }

        String cleaned =
                value.trim();

        if (cleaned.isEmpty()) {
            return null;
        }

        return cleaned;
    }

    /**
     * Convierte un valor a Long.
     *
     * Si el valor está vacío o no contiene un número válido,
     * retorna null para que el Processor pueda manejarlo.
     */
    public static Long parseLong(String value) {

        String cleaned =
                parseString(value);

        if (cleaned == null) {
            return null;
        }

        try {

            return Long.valueOf(
                    cleaned
            );

        } catch (NumberFormatException exception) {

            return null;
        }
    }

    /**
     * Convierte un valor a Integer.
     *
     * Si el valor está vacío o posee un formato inválido,
     * retorna null.
     */
    public static Integer parseInteger(String value) {

        String cleaned =
                parseString(value);

        if (cleaned == null) {
            return null;
        }

        try {

            return Integer.valueOf(
                    cleaned
            );

        } catch (NumberFormatException exception) {

            return null;
        }
    }

    /**
     * Convierte un valor a BigDecimal.
     *
     * Se mantienen tanto valores positivos como negativos.
     * La interpretación del signo corresponde posteriormente
     * a las reglas de negocio del Processor.
     *
     * Si el valor está vacío o posee un formato inválido,
     * retorna null.
     */
    public static BigDecimal parseBigDecimal(String value) {

        String cleaned =
                parseString(value);

        if (cleaned == null) {
            return null;
        }

        try {

            return new BigDecimal(
                    cleaned
            );

        } catch (NumberFormatException exception) {

            return null;
        }
    }

    /**
     * Convierte una fecha proveniente del sistema legacy.
     *
     * Formatos admitidos:
     *
     * yyyy-MM-dd
     * dd-MM-yyyy
     * dd/MM/yyyy
     * yyyy/MM/dd
     *
     * Se utiliza validación STRICT para impedir que fechas
     * imposibles sean corregidas silenciosamente.
     *
     * Ejemplo:
     *
     * 2024-13-01
     *
     * no corresponde a una fecha válida y retorna null.
     */
    public static LocalDate parseLocalDate(String value) {

        String cleaned =
                parseString(value);

        if (cleaned == null) {
            return null;
        }

        /*
         * Se prueban uno a uno los formatos legacy conocidos.
         */
        for (DateTimeFormatter formatter
                : FORMATOS_FECHA) {

            try {

                return LocalDate.parse(
                        cleaned,
                        formatter
                );

            } catch (
                    DateTimeParseException ignored
            ) {

                /*
                 * Si el formato actual no coincide,
                 * se intenta con el siguiente.
                 */
            }
        }

        /*
         * Ningún formato pudo interpretar la fecha.
         *
         * Se devuelve null para que el Processor aplique
         * la regla correspondiente.
         */
        return null;
    }
}
