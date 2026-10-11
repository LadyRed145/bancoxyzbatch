package cl.duoc.bancoxyz.cuentas.dto;

import jakarta.validation.Validation;
import jakarta.validation.Validator;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Reglas de Bean Validation sin necesidad de conectarse a PostgreSQL. */
class CuentasGestionValidacionTest {
 @Test void aperturaValidaRechazaDatosInvalidos(){
  try(var factory=Validation.buildDefaultValidatorFactory()){
   Validator validator=factory.getValidator();
   assertFalse(validator.validate(new AperturaCuentaRequest("","INVENTADO",new BigDecimal("-1.00"))).isEmpty());
   assertTrue(validator.validate(new AperturaCuentaRequest("Ana","CORRIENTE",BigDecimal.ZERO)).isEmpty());
  }
 }
 @Test void mantenimientoRechazaTitularVacio(){
  try(var factory=Validation.buildDefaultValidatorFactory()){
   assertFalse(factory.getValidator().validate(new MantenimientoCuentaRequest("  ")).isEmpty());
  }
 }
}
