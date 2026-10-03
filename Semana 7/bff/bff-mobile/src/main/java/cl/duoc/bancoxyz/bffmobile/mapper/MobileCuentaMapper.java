package cl.duoc.bancoxyz.bffmobile.mapper;

import cl.duoc.bancoxyz.bffmobile.dto.MobileCuentaResumen;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Map;

@Component
public class MobileCuentaMapper {

    public MobileCuentaResumen aResumen(Map<String, Object> cuenta) {
        // En Mobile transformo la entidad extensa del backend a un contrato pequeño y estable para el canal.
        return new MobileCuentaResumen(
                obtenerLong(cuenta, "cuentaId"),
                (String) cuenta.get("nombre"),
                (String) cuenta.get("tipo"),
                (String) cuenta.get("estado"),
                convertirBigDecimal(cuenta.get("saldoFinal"))
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
            return BigDecimal.ZERO;
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
