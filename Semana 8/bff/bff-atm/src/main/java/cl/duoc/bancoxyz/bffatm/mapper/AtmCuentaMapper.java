package cl.duoc.bancoxyz.bffatm.mapper;

import cl.duoc.bancoxyz.bffatm.dto.AtmCuentaSaldo;
import cl.duoc.bancoxyz.bffatm.dto.AtmRetiroResponse;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Map;

@Component
public class AtmCuentaMapper {

    public AtmCuentaSaldo aSaldo(Map<String, Object> cuenta) {
        // Para el ATM reduzco la respuesta a identificación y saldo; no expongo campos internos que no utiliza.
        return new AtmCuentaSaldo(
                obtenerLong(cuenta, "cuentaId"),
                (String) cuenta.get("nombre"),
                convertirBigDecimal(cuenta.get("saldoFinal"))
        );
    }

    public AtmRetiroResponse aRetiro(Map<String, Object> cuentaActualizada, BigDecimal monto) {
        // Después de un retiro devuelvo solo lo que necesita la interfaz del cajero para confirmar la operación.
        return new AtmRetiroResponse(
                obtenerLong(cuentaActualizada, "cuentaId"),
                monto,
                convertirBigDecimal(cuentaActualizada.get("saldoFinal"))
        );
    }

    private Long obtenerLong(Map<String, Object> datos, String clave) {
        Object valor = datos.get(clave);

        if (!(valor instanceof Number numero)) {
            throw new IllegalStateException(
                    "El backend devolvió un valor inválido para " + clave
            );
        }

        return numero.longValue();
    }

    private BigDecimal convertirBigDecimal(Object valor) {
        if (valor == null) {
            throw new IllegalStateException(
                    "El backend no devolvió un valor monetario esperado"
            );
        }

        if (valor instanceof BigDecimal bigDecimal) {
            return bigDecimal;
        }

        if (valor instanceof Number numero) {
            return new BigDecimal(numero.toString());
        }

        return new BigDecimal(valor.toString());
    }
}
