package cl.duoc.bancoxyz.bffatm.dto;

import java.math.BigDecimal;

public class AtmRetiroRequest {

    private BigDecimal monto;

    public AtmRetiroRequest(BigDecimal monto) {
        this.monto = monto;
    }

    public BigDecimal getMonto() {
        return monto;
    }

    public void setMonto(BigDecimal monto) {
        this.monto = monto;
    }
}