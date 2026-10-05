package cl.duoc.bancoxyz.event;

public class RetiroRealizadoEvent {

    private Long cuentaId;
    private double monto;
    private double saldoFinal;
    private String tipo;

    public RetiroRealizadoEvent() {
    }

    public RetiroRealizadoEvent(Long cuentaId, double monto, double saldoFinal, String tipo) {
        this.cuentaId = cuentaId;
        this.monto = monto;
        this.saldoFinal = saldoFinal;
        this.tipo = tipo;
    }

    public Long getCuentaId() { return cuentaId; }
    public void setCuentaId(Long cuentaId) { this.cuentaId = cuentaId; }
    public double getMonto() { return monto; }
    public void setMonto(double monto) { this.monto = monto; }
    public double getSaldoFinal() { return saldoFinal; }
    public void setSaldoFinal(double saldoFinal) { this.saldoFinal = saldoFinal; }
    public String getTipo() { return tipo; }
    public void setTipo(String tipo) { this.tipo = tipo; }
}
