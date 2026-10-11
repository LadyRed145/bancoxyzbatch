package cl.duoc.bancoxyz.cuentas.service;

import cl.duoc.bancoxyz.cuentas.dto.*;
import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Pruebas unitarias: no levantan Spring, Docker ni PostgreSQL. */
class CuentasGestionServiceTest {
 private JdbcTemplate jdbc;
 private CuentasGestionService service;
 private final CuentaGestionResponse activa = new CuentaGestionResponse(7L,"Ana","AHORRO","ACTIVA",new BigDecimal("100.00"));

 @BeforeEach void preparar(){jdbc=mock(JdbcTemplate.class);service=new CuentasGestionService(jdbc);}

 @Test void aperturaDevuelveIdentificadorPostgresql(){
  when(jdbc.queryForObject(contains("RETURNING id"),eq(Long.class),any(),any(),any())).thenReturn(7L);
  when(jdbc.query(anyString(),org.mockito.ArgumentMatchers.<RowMapper<CuentaGestionResponse>>any(),eq(7L)))
      .thenReturn(List.of(activa));
  var nueva=service.abrir(new AperturaCuentaRequest(" Ana ","AHORRO",new BigDecimal("100.00")));
  assertEquals(7L,nueva.id());
  verify(jdbc).queryForObject(contains("RETURNING id"),eq(Long.class),eq("Ana"),eq("AHORRO"),eq(new BigDecimal("100.00")));
 }

 @Test void aperturaSinIdFalla(){
  when(jdbc.queryForObject(anyString(),eq(Long.class),any(),any(),any())).thenReturn(null);
  assertThrows(IllegalStateException.class,()->service.abrir(new AperturaCuentaRequest("Ana","AHORRO",BigDecimal.ZERO)));
 }

 @Test void mantenimientoActualizaSoloCuentasActivas(){
  when(jdbc.update(contains("estado='ACTIVA'"),eq("Ana Maria"),eq(7L))).thenReturn(1);
  when(jdbc.query(anyString(),org.mockito.ArgumentMatchers.<RowMapper<CuentaGestionResponse>>any(),eq(7L)))
      .thenReturn(List.of(activa));
  assertEquals(7L,service.actualizar(7L,new MantenimientoCuentaRequest(" Ana Maria ")).id());
 }

 @Test void mantenimientoCuentaNoActivaDevuelveConflicto(){
  when(jdbc.update(anyString(),anyString(),eq(7L))).thenReturn(0);
  var ex=assertThrows(ResponseStatusException.class,()->service.actualizar(7L,new MantenimientoCuentaRequest("Ana")));
  assertEquals(HttpStatus.CONFLICT,ex.getStatusCode());
 }

 @Test void cierreRepetidoDevuelveConflicto(){
  when(jdbc.update(contains("estado='ACTIVA'"),eq(7L))).thenReturn(0);
  var ex=assertThrows(ResponseStatusException.class,()->service.cerrar(7L));
  assertEquals(HttpStatus.CONFLICT,ex.getStatusCode());
 }

 @Test void cuentaInexistenteDevuelveNotFound(){
  when(jdbc.query(anyString(),org.mockito.ArgumentMatchers.<RowMapper<CuentaGestionResponse>>any(),eq(999L)))
      .thenReturn(List.of());
  var ex=assertThrows(ResponseStatusException.class,()->service.obtener(999L));
  assertEquals(HttpStatus.NOT_FOUND,ex.getStatusCode());
 }
}
