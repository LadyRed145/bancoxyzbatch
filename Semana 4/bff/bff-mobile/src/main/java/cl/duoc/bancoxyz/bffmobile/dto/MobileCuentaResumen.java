package cl.duoc.bancoxyz.bffmobile.dto;

public class MobileCuentaResumen {

    private Long cuentaId;
    private String nombre;
    private String tipo;
    private String estado;
    private Object saldoFinal;

    public MobileCuentaResumen(
            Long cuentaId,
            String nombre,
            String tipo,
            String estado,
            Object saldoFinal) {

        this.cuentaId = cuentaId;
        this.nombre = nombre;
        this.tipo = tipo;
        this.estado = estado;
        this.saldoFinal = saldoFinal;
    }

    public Long getCuentaId() {
        return cuentaId;
    }

    public String getNombre() {
        return nombre;
    }

    public String getTipo() {
        return tipo;
    }

    public String getEstado() {
        return estado;
    }

    public Object getSaldoFinal() {
        return saldoFinal;
    }
}