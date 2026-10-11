package cl.duoc.bancoxyz.cuentas.controller;

import cl.duoc.bancoxyz.cuentas.dto.*;
import cl.duoc.bancoxyz.cuentas.service.CuentasGestionService;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** Pruebas unitarias del contrato del controlador, sin servidor HTTP ni BD. */
class CuentasGestionControllerTest {
 @Test void aperturaRespondeCreatedYLocation(){
  var service=mock(CuentasGestionService.class);
  var controller=new CuentasGestionController(service);
  var response=new CuentaGestionResponse(5L,"Ana","AHORRO","ACTIVA",BigDecimal.ZERO);
  when(service.abrir(any(AperturaCuentaRequest.class))).thenReturn(response);
  var result=controller.abrir(new AperturaCuentaRequest("Ana","AHORRO",BigDecimal.ZERO));
  assertEquals(HttpStatus.CREATED,result.getStatusCode());
  assertEquals("/api/cuentas/gestion/5",result.getHeaders().getLocation().toString());
  assertEquals(response,result.getBody());
 }
 @Test void cierreDelegaAlServicio(){
  var service=mock(CuentasGestionService.class);
  var controller=new CuentasGestionController(service);
  var response=new CuentaGestionResponse(5L,"Ana","AHORRO","CERRADA",BigDecimal.ZERO);
  when(service.cerrar(5L)).thenReturn(response);
  assertEquals("CERRADA",controller.cerrar(5L).estado());
  verify(service).cerrar(5L);
 }
}
