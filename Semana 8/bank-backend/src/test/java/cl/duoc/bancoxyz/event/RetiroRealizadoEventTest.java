package cl.duoc.bancoxyz.event;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;

class RetiroRealizadoEventTest {

    @Test
    void conservaPrecisionMonetariaEnElContratoKafka() {
        BigDecimal monto = new BigDecimal("10.25");
        BigDecimal saldoFinal = new BigDecimal("1234.75");

        RetiroRealizadoEvent evento = new RetiroRealizadoEvent(
                101L,
                monto,
                saldoFinal,
                "RETIRO"
        );

        assertEquals(monto, evento.getMonto());
        assertEquals(saldoFinal, evento.getSaldoFinal());
        assertEquals(101L, evento.getCuentaId());
        assertEquals("RETIRO", evento.getTipo());
    }
}
