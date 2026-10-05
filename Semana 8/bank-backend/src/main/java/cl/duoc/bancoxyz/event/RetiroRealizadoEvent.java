package cl.duoc.bancoxyz.event;

import java.math.BigDecimal;

/**
 * Contrato del evento publicado por bank-backend cuando un retiro se procesa.
 * BigDecimal conserva la precisión monetaria del dominio hasta el mensaje Kafka.
 */
public class RetiroRealizadoEvent {

    private Long cuentaId;
    private BigDecimal monto;
    private BigDecimal saldoFinal;
    private String tipo;

    public RetiroRealizadoEvent() {
    }

    public RetiroRealizadoEvent(
            Long cuentaId,
            BigDecimal monto,
            BigDecimal saldoFinal,
            String tipo
    ) {
        this.cuentaId = cuentaId;
        this.monto = monto;
        this.saldoFinal = saldoFinal;
        this.tipo = tipo;
    }

    public Long getCuentaId() {
        return cuentaId;
    }

    public void setCuentaId(Long cuentaId) {
        this.cuentaId = cuentaId;
    }

    public BigDecimal getMonto() {
        return monto;
    }

    public void setMonto(BigDecimal monto) {
        this.monto = monto;
    }

    public BigDecimal getSaldoFinal() {
        return saldoFinal;
    }

    public void setSaldoFinal(BigDecimal saldoFinal) {
        this.saldoFinal = saldoFinal;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }
}
