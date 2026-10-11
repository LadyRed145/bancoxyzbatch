package cl.duoc.bancoxyz.pagos;

import cl.duoc.bancoxyz.pagos.PagosController.Solicitud;
import cl.duoc.bancoxyz.pagos.PagosController.Tipo;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Pruebas de reglas y SQL emitido: sin efectos en PostgreSQL real. */
@ExtendWith(MockitoExtension.class)
class PagosServiceTest {
    @Mock JdbcTemplate jdbc;
    PagosService pagos;
    UUID id;

    @BeforeEach
    void preparar() {
        pagos = new PagosService(jdbc);
        id = UUID.randomUUID();
    }

    void simular(Solicitud s, int insercion, String estadoExistente, boolean saldoSuficiente) {
        when(jdbc.update(anyString(), any(Object[].class))).thenAnswer(inv -> {
            String sql = inv.getArgument(0, String.class).strip();
            if (sql.startsWith("INSERT INTO pagos_solicitudes")) return insercion;
            if (sql.startsWith("UPDATE pagos_saldos SET saldo_actual=saldo_actual-"))
                return saldoSuficiente ? 1 : 0;
            return 1;
        });
        when(jdbc.queryForList(anyString(), any(Object[].class))).thenAnswer(inv -> {
            String sql = inv.getArgument(0, String.class).strip();
            if (sql.startsWith("SELECT tipo,origen,destino,monto,estado"))
                return List.of(Map.of("tipo",s.tipo().name(),"origen",s.origen(),
                        "destino",s.destino(),"monto",s.monto(),"estado",estadoExistente));
            if (sql.startsWith("SELECT id,estado FROM cuentas_gestion"))
                return List.of(Map.of("estado","ACTIVA"));
            if (sql.startsWith("SELECT cuenta_id FROM pagos_saldos"))
                return List.of(Map.of("cuenta_id",s.destino()));
            return List.of();
        });
    }

    @Test
    void transferenciaDebitaYAcreditaEnUnaSolicitud() {
        var req = new Solicitud(Tipo.TRANSFERENCIA,10,20,new BigDecimal("12.50"));
        simular(req,1,"PENDIENTE",true);
        assertEquals("APLICADO",pagos.procesar(id,req).estado());
        verify(jdbc).update(startsWith("UPDATE pagos_saldos SET saldo_actual=saldo_actual-"),any(Object[].class));
        verify(jdbc).update(startsWith("UPDATE pagos_saldos SET saldo_actual=saldo_actual+"),any(Object[].class));
        verify(jdbc,times(2)).update(startsWith("INSERT INTO pagos_movimientos"),any(Object[].class));
    }

    @Test
    void pagoDebitaYAcreditaIgualQueTransferenciaPeroConTipoPago() {
        var req=new Solicitud(Tipo.PAGO,10,20,new BigDecimal("8.00"));
        simular(req,1,"PENDIENTE",true);
        assertEquals(Tipo.PAGO,pagos.procesar(id,req).tipo());
        verify(jdbc,times(2)).update(startsWith("INSERT INTO pagos_movimientos"),any(Object[].class));
    }

    @Test
    void depositoSoloAcreditaElDestino() {
        var req=new Solicitud(Tipo.DEPOSITO,99,20,new BigDecimal("50.00"));
        simular(req,1,"PENDIENTE",true);
        assertEquals("APLICADO",pagos.procesar(id,req).estado());
        verify(jdbc,never()).update(startsWith("UPDATE pagos_saldos SET saldo_actual=saldo_actual-"),any(Object[].class));
        verify(jdbc,times(1)).update(startsWith("INSERT INTO pagos_movimientos"),any(Object[].class));
    }

    @Test
    void idempotencyKeyRepetidaNoMueveDinero() {
        var req=new Solicitud(Tipo.TRANSFERENCIA,10,20,new BigDecimal("5.00"));
        simular(req,0,"APLICADO",true);
        assertEquals("APLICADO",pagos.procesar(id,req).estado());
        verify(jdbc,never()).update(startsWith("UPDATE pagos_saldos"),any(Object[].class));
        verify(jdbc,never()).update(startsWith("INSERT INTO pagos_movimientos"),any(Object[].class));
    }

    @Test
    void fondosInsuficientesImpidenAcreditarDestino() {
        var req=new Solicitud(Tipo.TRANSFERENCIA,10,20,new BigDecimal("900.00"));
        simular(req,1,"PENDIENTE",false);
        assertThrows(ResponseStatusException.class, () -> pagos.procesar(id,req));
        verify(jdbc,never()).update(startsWith("UPDATE pagos_saldos SET saldo_actual=saldo_actual+"),any(Object[].class));
    }

    @Test
    void pendienteHistoricoNoSeEjecutaAutomaticamente() {
        var req=new Solicitud(Tipo.PAGO,10,20,new BigDecimal("8.00"));
        simular(req,0,"PENDIENTE",true);
        assertThrows(ResponseStatusException.class, () -> pagos.procesar(id,req));
        verify(jdbc,never()).update(startsWith("INSERT INTO pagos_movimientos"),any(Object[].class));
    }

    @Test
    void tipoYCuentaIgualNoSonValidos() {
        var req=new Solicitud(Tipo.TRANSFERENCIA,10,10,new BigDecimal("1.00"));
        assertThrows(ResponseStatusException.class,()->pagos.procesar(id,req));
        verifyNoInteractions(jdbc);
    }
}
