package cl.duoc.bancoxyz.clientes;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.util.*;
@RestController @RequestMapping("/api/clientes") public class ClientesController {
 private final JdbcClient db;
 public ClientesController(JdbcClient db){this.db=db;}
 public record Form(@NotBlank @Size(max=120) String nombre,@NotBlank @Email String correo){}
 public record Cliente(long id,String nombre,String correo,boolean activo){}
 @GetMapping public List<Cliente> listar(){return db.sql("select id,nombre,correo,activo from clientes_perfil order by id").query((r,i)->new Cliente(r.getLong(1),r.getString(2),r.getString(3),r.getBoolean(4))).list();}
 @GetMapping("/{id}") public Cliente consultar(@PathVariable long id){return db.sql("select id,nombre,correo,activo from clientes_perfil where id=:id").param("id",id).query((r,i)->new Cliente(r.getLong(1),r.getString(2),r.getString(3),r.getBoolean(4))).optional().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));}
 @PostMapping @ResponseStatus(HttpStatus.CREATED) public Cliente crear(@Valid @RequestBody Form f){Long id=db.sql("insert into clientes_perfil(nombre,correo) values (:nombre,:correo) returning id").param("nombre",f.nombre()).param("correo",f.correo()).query(Long.class).single();return consultar(id);}
 @PutMapping("/{id}") public Cliente actualizar(@PathVariable long id,@Valid @RequestBody Form f){int n=db.sql("update clientes_perfil set nombre=:nombre,correo=:correo where id=:id and activo=true").param("nombre",f.nombre()).param("correo",f.correo()).param("id",id).update();if(n==0)throw new ResponseStatusException(HttpStatus.NOT_FOUND);return consultar(id);}
 @PostMapping("/{id}/desactivar") public Cliente desactivar(@PathVariable long id){int n=db.sql("update clientes_perfil set activo=false where id=:id and activo=true").param("id",id).update();if(n==0)throw new ResponseStatusException(HttpStatus.CONFLICT,"No existe cliente activo");return consultar(id);}
}
