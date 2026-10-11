package cl.duoc.bancoxyz.backend.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.util.UUID;

/** Recibo transaccional para impedir un segundo débito con la misma clave. */
@Entity
@Table(name = "retiros_idempotencia")
public class RetiroIdempotencia {
    @Id
    @Column(name = "clave", nullable = false)
    private UUID clave;
    @Column(name = "cuenta_id", nullable = false)
    private Long cuentaId;
    @Column(name = "monto", nullable = false, precision = 19, scale = 2)
    private BigDecimal monto;
    @Column(name = "saldo_final", nullable = false, precision = 19, scale = 2)
    private BigDecimal saldoFinal;

    protected RetiroIdempotencia() { }
    public RetiroIdempotencia(UUID clave, Long cuentaId, BigDecimal monto, BigDecimal saldoFinal) {
        this.clave = clave;
        this.cuentaId = cuentaId;
        this.monto = monto;
        this.saldoFinal = saldoFinal;
    }
    public UUID getClave() { return clave; }
    public Long getCuentaId() { return cuentaId; }
    public BigDecimal getMonto() { return monto; }
    public BigDecimal getSaldoFinal() { return saldoFinal; }
}
