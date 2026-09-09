package cl.duoc.bancoxyz.bffatm.dto;

public class AtmCuentaSaldo {

    private Long cuentaId;
    private String nombre;
    private Object saldoDisponible;

    public AtmCuentaSaldo(
            Long cuentaId,
            String nombre,
            Object saldoDisponible) {

        this.cuentaId = cuentaId;
        this.nombre = nombre;
        this.saldoDisponible = saldoDisponible;
    }

    public Long getCuentaId() {
        return cuentaId;
    }

    public String getNombre() {
        return nombre;
    }

    public Object getSaldoDisponible() {
        return saldoDisponible;
    }
}