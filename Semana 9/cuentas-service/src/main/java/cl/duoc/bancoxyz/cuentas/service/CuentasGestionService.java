package cl.duoc.bancoxyz.cuentas.service;
import cl.duoc.bancoxyz.cuentas.dto.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
/** Gestion aislada: no actualiza cuentas_intereses ni saldos del legacy. */
@Service
public class CuentasGestionService {
 private final JdbcTemplate jdbc;
 public CuentasGestionService(JdbcTemplate jdbc) {this.jdbc=jdbc;}
 private final org.springframework.jdbc.core.RowMapper<CuentaGestionResponse> mapper=(rs,n)->new CuentaGestionResponse(rs.getLong("id"),rs.getString("titular"),rs.getString("tipo"),rs.getString("estado"),rs.getBigDecimal("saldo_inicial"));
 @Transactional(readOnly=true)
 public List<CuentaGestionResponse> listar(){return jdbc.query("SELECT id,titular,tipo,estado,saldo_inicial FROM cuentas_gestion ORDER BY id",mapper);}
 @Transactional(readOnly=true)
 public CuentaGestionResponse obtener(long id){
  return jdbc.query("SELECT id,titular,tipo,estado,saldo_inicial FROM cuentas_gestion WHERE id=?",mapper,id)
   .stream().findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Cuenta no encontrada"));
 }
 @Transactional
 public CuentaGestionResponse abrir(AperturaCuentaRequest req){
  // PostgreSQL devuelve únicamente el ID: evita ambigüedad en claves generadas.
  Long id=jdbc.queryForObject(
   "INSERT INTO cuentas_gestion(titular,tipo,estado,saldo_inicial) VALUES (?,?,'ACTIVA',?) RETURNING id",
   Long.class,req.titular().trim(),req.tipo(),req.saldoInicial());
  if(id==null) throw new IllegalStateException("PostgreSQL no devolvio el identificador");
  return obtener(id);
 }
 @Transactional
 public CuentaGestionResponse actualizar(long id,MantenimientoCuentaRequest req){
  int n=jdbc.update("UPDATE cuentas_gestion SET titular=?,actualizado_en=CURRENT_TIMESTAMP WHERE id=? AND estado='ACTIVA'",req.titular().trim(),id);
  if(n==0) throw new ResponseStatusException(HttpStatus.CONFLICT,"Cuenta inexistente o cerrada");
  return obtener(id);
 }
 @Transactional
 public CuentaGestionResponse cerrar(long id){
  int n=jdbc.update("UPDATE cuentas_gestion SET estado='CERRADA',actualizado_en=CURRENT_TIMESTAMP WHERE id=? AND estado='ACTIVA'",id);
  if(n==0) throw new ResponseStatusException(HttpStatus.CONFLICT,"Cuenta inexistente o ya cerrada");
  return obtener(id);
 }
}
