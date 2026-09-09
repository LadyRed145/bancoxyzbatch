package cl.duoc.bancoxyz.bffweb.dto;

public class WebCuentaDetalle {

    private Object cuenta;
    private Object estadosCuenta;

    public WebCuentaDetalle(Object cuenta, Object estadosCuenta) {
        this.cuenta = cuenta;
        this.estadosCuenta = estadosCuenta;
    }

    public Object getCuenta() {
        return cuenta;
    }

    public Object getEstadosCuenta() {
        return estadosCuenta;
    }
}