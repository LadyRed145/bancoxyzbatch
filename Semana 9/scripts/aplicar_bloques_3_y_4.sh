#!/usr/bin/env bash
# BancoXYZ EFT S9 - Bloques 3 + 4. Ejecutar desde Fish mediante 'bash'.
# No elimina bases ni CSV. Sin backups/snapshots automáticos.
set -euo pipefail
if ! command -v python3 >/dev/null; then echo 'ERROR: se requiere python3'; exit 2; fi
if [[ ! -d 'Semana 9' ]]; then echo 'ERROR: ejecuta desde la raiz de bancoxyzbatch'; exit 2; fi
BASE="$PWD"
MODO="${1:---aplicar}"
case "$MODO" in --todo|--aplicar|--validar|--migrar|--cargar-csv) ;; *) echo "Modo desconocido: $MODO. Usa --todo, --aplicar, --migrar, --cargar-csv o --validar"; exit 2;; esac
if [[ "$MODO" == '--todo' ]]; then
    bash "$0" --aplicar
    bash "$0" --migrar
    bash "$0" --cargar-csv
    bash "$0" --validar
    echo 'OK: pipeline completo; sin eliminar snapshot ni BD antigua.'
    exit 0
fi
if [[ "$MODO" == '--aplicar' ]]; then
python3 - "$BASE" <<'PYCODE'
from pathlib import Path
import sys, re, os, hashlib, tempfile, subprocess
root=Path(sys.argv[1]); s9=root/'Semana 9'
patches={}

def content(rel):
    p=root/rel
    if not p.is_file(): raise RuntimeError('Falta archivo: '+str(p))
    return patches.get(p,p.read_text(encoding='utf-8'))

def save(rel, txt):
    patches[root/rel]=txt

def replace(rel, old, new, marker=None):
    txt=content(rel)
    if (marker or new) in txt: return
    elif old in txt:
        if txt.count(old)!=1: raise RuntimeError('Coincidencia ambigua: '+rel)
        save(rel,txt.replace(old,new,1))
    else: raise RuntimeError('Archivo distinto del auditado: '+rel+'; sin cambios aplicados')

# A. Recibo durable: cada UUID solo descuenta una vez y resiste reinicios.
base='Semana 9/bank-backend/src/main/java/cl/duoc/bancoxyz/backend/'
entity=base+'entity/RetiroIdempotencia.java'
repo=base+'repository/RetiroIdempotenciaRepository.java'
entity_body='''package cl.duoc.bancoxyz.backend.entity;

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
'''
repo_body='''package cl.duoc.bancoxyz.backend.repository;

import cl.duoc.bancoxyz.backend.entity.RetiroIdempotencia;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;

public interface RetiroIdempotenciaRepository extends JpaRepository<RetiroIdempotencia, UUID> { }
'''
for rel,body in [(entity,entity_body),(repo,repo_body)]:
    p=root/rel
    if p.exists() and p.read_text(encoding='utf-8')!=body:
        raise RuntimeError('Archivo nuevo ya existe con otro contenido: '+rel)
    save(rel,body)
service=base+'service/CuentaInteresService.java'
replace(service,'import cl.duoc.bancoxyz.backend.entity.CuentaInteres;','import cl.duoc.bancoxyz.backend.entity.CuentaInteres;\nimport cl.duoc.bancoxyz.backend.entity.RetiroIdempotencia;\nimport cl.duoc.bancoxyz.backend.repository.RetiroIdempotenciaRepository;\nimport org.springframework.http.HttpStatus;\nimport org.springframework.web.server.ResponseStatusException;'.replace('\\n','\n'))
replace(service,'import java.util.Optional;','import java.util.Optional;\nimport java.util.UUID;'.replace('\\n','\n'))
replace(service,'''    private final RetiroKafkaProducer retiroKafkaProducer;

    public CuentaInteresService(
            CuentaInteresRepository repository,
            RetiroKafkaProducer retiroKafkaProducer) {

        this.repository = repository;
        this.retiroKafkaProducer = retiroKafkaProducer;
    }''','''    private final RetiroKafkaProducer retiroKafkaProducer;
    private final RetiroIdempotenciaRepository recibos;

    public CuentaInteresService(
            CuentaInteresRepository repository,
            RetiroKafkaProducer retiroKafkaProducer,
            RetiroIdempotenciaRepository recibos) {

        this.repository = repository;
        this.retiroKafkaProducer = retiroKafkaProducer;
        this.recibos = recibos;
    }''')
replace(service,'''    @Transactional
    public CuentaInteres retirar(Long cuentaId, BigDecimal monto) {

        if (monto == null''','''    @Transactional
    public CuentaInteres retirar(Long cuentaId, BigDecimal monto) {
        return retirar(cuentaId, monto, null);
    }

    /** Si el cliente incluye Idempotency-Key, un reintento no repite el débito. */
    @Transactional
    public CuentaInteres retirar(Long cuentaId, BigDecimal monto, UUID clave) {

        if (monto == null''')
replace(service,'''        if (!Boolean.TRUE.equals(cuenta.getActivo())) {''','''        // Se consulta BAJO el lock de cuenta para serializar los reintentos.
        // El registro del recibo y el descuento comparten transacción SQL.
        if (clave != null) {
            Optional<RetiroIdempotencia> anterior = recibos.findById(clave);
            if (anterior.isPresent()) {
                RetiroIdempotencia r = anterior.get();
                if (!r.getCuentaId().equals(cuentaId) || r.getMonto().compareTo(monto) != 0) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT,
                            "Idempotency-Key ya utilizada en una operación distinta");
                }
                // No se descuenta ni se emite un segundo evento Kafka.
                return cuenta;
            }
        }

        if (!Boolean.TRUE.equals(cuenta.getActivo())) {''')
replace(service,'''        CuentaInteres cuentaActualizada = repository.saveAndFlush(cuenta);

        RetiroRealizadoEvent evento''','''        CuentaInteres cuentaActualizada = repository.saveAndFlush(cuenta);
        if (clave != null) {
            // El INSERT será revertido si la transacción del retiro falla.
            recibos.saveAndFlush(new RetiroIdempotencia(
                    clave, cuentaId, monto, cuentaActualizada.getSaldoFinal()));
        }

        RetiroRealizadoEvent evento''')
controller=base+'controller/CuentaController.java'
replace(controller,'import org.springframework.web.bind.annotation.GetMapping;','import org.springframework.web.bind.annotation.GetMapping;\nimport org.springframework.web.bind.annotation.RequestHeader;'.replace('\\n','\n'))
replace(controller,'import java.util.List;','import java.util.List;\nimport java.util.UUID;'.replace('\\n','\n'))
replace(controller,'''            @PathVariable Long id,
            @Valid @RequestBody RetiroRequest request) {

        return service.retirar(id, request.getMonto());''','''            @PathVariable Long id,
            @RequestHeader(value = "Idempotency-Key", required = false) UUID clave,
            @Valid @RequestBody RetiroRequest request) {

        return service.retirar(id, request.getMonto(), clave);''')
# C. ATM transmite UUID del cliente, sin inventar uno nuevo en cada reintento.
cb='Semana 9/bff/bff-atm/src/main/java/cl/duoc/bancoxyz/bffatm/'
ctl=cb+'controller/AtmCuentaController.java'
replace(ctl,'import org.springframework.web.bind.annotation.GetMapping;','import org.springframework.web.bind.annotation.GetMapping;\nimport org.springframework.web.bind.annotation.RequestHeader;'.replace('\\n','\n'))
replace(ctl,'import jakarta.validation.Valid;','import jakarta.validation.Valid;\nimport java.util.UUID;'.replace('\\n','\n'))
replace(ctl,'''            @PathVariable Long id,
            @Valid @RequestBody AtmRetiroRequest request) {

        // El controlador solo valida el contrato HTTP; la regla financiera sigue viviendo en el backend central.
        return atmCuentaService.retirar(id, request.monto());''','''            @PathVariable Long id,
            @RequestHeader(value = "Idempotency-Key", required = false) UUID clave,
            @Valid @RequestBody AtmRetiroRequest request) {

        // Conserva la clave del cliente en toda la cadena ATM -> backend.
        return atmCuentaService.retirar(id, request.monto(), clave);''')
serv=cb+'service/AtmCuentaService.java'
replace(serv,'import java.util.Map;','import java.util.Map;\nimport java.util.UUID;'.replace('\\n','\n'))
replace(serv,'''    public AtmRetiroResponse retirar(Long id, BigDecimal monto) {
        AtmRetiroRequest request = new AtmRetiroRequest(monto);
        Map<String, Object> cuentaActualizada = bankBackendClient.retirar(id, request).block();''','''    public AtmRetiroResponse retirar(Long id, BigDecimal monto) {
        return retirar(id, monto, null);
    }

    public AtmRetiroResponse retirar(Long id, BigDecimal monto, UUID clave) {
        AtmRetiroRequest request = new AtmRetiroRequest(monto);
        Map<String, Object> cuentaActualizada = bankBackendClient.retirar(id, request, clave).block();''')
client=cb+'client/BankBackendClient.java'
replace(client,'import java.time.Duration;','import java.time.Duration;\nimport java.util.UUID;'.replace('\\n','\n'))
replace(client,'''    public Mono<Map<String, Object>> retirar(Long id, AtmRetiroRequest request) {
        String jwtBackend = jwtParaBackend();''','''    public Mono<Map<String, Object>> retirar(Long id, AtmRetiroRequest request) {
        return retirar(id, request, null);
    }

    public Mono<Map<String, Object>> retirar(Long id, AtmRetiroRequest request, UUID clave) {
        String jwtBackend = jwtParaBackend();''')
replace(client,'''                        .headers(headers -> headers.setBearerAuth(jwtBackend))
                        .bodyValue(request)''','''                        .headers(headers -> {
                            headers.setBearerAuth(jwtBackend);
                            if (clave != null) headers.set("Idempotency-Key", clave.toString());
                        })
                        .bodyValue(request)''')
# D. El test anterior debe usar el nuevo constructor y debe probar el reintento.
test='Semana 9/bank-backend/src/test/java/cl/duoc/bancoxyz/backend/service/CuentaInteresServiceTest.java'
replace(test,'import cl.duoc.bancoxyz.backend.entity.CuentaInteres;','import cl.duoc.bancoxyz.backend.entity.CuentaInteres;\nimport cl.duoc.bancoxyz.backend.entity.RetiroIdempotencia;\nimport cl.duoc.bancoxyz.backend.repository.RetiroIdempotenciaRepository;'.replace('\\n','\n'))
replace(test,'import java.util.Optional;','import java.util.Optional;\nimport java.util.UUID;'.replace('\\n','\n'))
replace(test,'''    private final RetiroKafkaProducer producer = mock(RetiroKafkaProducer.class);
    private final CuentaInteresService service = new CuentaInteresService(repository, producer);''','''    private final RetiroKafkaProducer producer = mock(RetiroKafkaProducer.class);
    private final RetiroIdempotenciaRepository recibos = mock(RetiroIdempotenciaRepository.class);
    private final CuentaInteresService service = new CuentaInteresService(repository, producer, recibos);''')
replace(test,'''    private void prepararCuenta() {''','''    @Test
    void reintentoConMismaClaveNoDescuentaNiPublica() {
        var clave = UUID.randomUUID();
        prepararCuenta();
        when(recibos.findById(clave)).thenReturn(Optional.of(
                new RetiroIdempotencia(clave, 11L,
                        new BigDecimal("10.00"), new BigDecimal("90.00"))));
        var resultado = service.retirar(11L, new BigDecimal("10.00"), clave);
        assertEquals(0, new BigDecimal("100.00").compareTo(resultado.getSaldoFinal()));
        verify(repository, never()).saveAndFlush(any());
        assertTrue(TransactionSynchronizationManager.getSynchronizations().isEmpty());
        verifyNoInteractions(producer);
    }

    @Test
    void claveReutilizadaConOtroMontoEsConflicto() {
        var clave = UUID.randomUUID();
        prepararCuenta();
        when(recibos.findById(clave)).thenReturn(Optional.of(
                new RetiroIdempotencia(clave, 11L,
                        new BigDecimal("10.00"), new BigDecimal("90.00"))));
        var error = assertThrows(org.springframework.web.server.ResponseStatusException.class,
                () -> service.retirar(11L, new BigDecimal("20.00"), clave));
        assertEquals(409, error.getStatusCode().value());
        verify(repository, never()).saveAndFlush(any());
    }

    private void prepararCuenta() {''')
# E. Consolidar la configuración de Batch al MISMO PostgreSQL lógico que el backend.
props='Semana 9/batch-service/src/main/resources/application.properties'
replace(props,'spring.datasource.url=${BATCH_DB_URL:jdbc:postgresql://127.0.0.1:5432/bancoxyz_batch_eft_aislado}',
       'spring.datasource.url=${BATCH_DB_URL:${DB_URL:jdbc:postgresql://127.0.0.1:5432/bancoxyz}}')
replace(props,'spring.datasource.username=${BATCH_DB_USER:batch_eft}',
       'spring.datasource.username=${BATCH_DB_USER:${DB_USER:bancoxyz}}')
replace(props,'spring.datasource.password=${BATCH_DB_PASSWORD:}',
       'spring.datasource.password=${BATCH_DB_PASSWORD:${DB_PASSWORD:}}')
p=content(props)
p=p.replace('# MODO AISLADO: No activar contra el PostgreSQL de la Semana 9.\n# La base bancoxyz_batch_eft_aislado NO se crea automaticamente.\n# Requiere una BD independiente y credenciales entregadas por variables BATCH_DB_*.\n# No hay autoejecucion de jobs; DDL y scripts SQL deshabilitados.\n',
            '# Base unificada. Los jobs NO se ejecutan automaticamente.\n# DDL y fuentes de datos solo se aplican cuando corresponda.\n')
save(props,p)
# F. Esquema aditivo de recibos, sin modificar datos ni CSV.
sqlrel='Semana 9/data/db/03_retiros_idempotencia.sql'
sql='''-- BancoXYZ Semana 9. Migración ADITIVA: segura al repetirla.
-- No elimina tablas, cuentas, CSV ni filas de negocio.
CREATE TABLE IF NOT EXISTS retiros_idempotencia (
  clave UUID PRIMARY KEY,
  cuenta_id BIGINT NOT NULL,
  monto NUMERIC(19,2) NOT NULL CHECK (monto > 0),
  saldo_final NUMERIC(19,2) NOT NULL,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_retiros_idemp_cuenta ON retiros_idempotencia(cuenta_id);
'''
q=root/sqlrel
if q.exists() and q.read_text(encoding='utf-8')!=sql: raise RuntimeError('Conflicto SQL: '+sqlrel)
save(sqlrel,sql)
# G. Compose existente: 1 sola instancia PostgreSQL con rutas de Semana 9.
compose='docker-compose.yml'
c=content(compose)
if 'services:' not in c or '  postgres:' not in c or 'bancoxyz_postgres_data:' not in c:
    raise RuntimeError('Compose no coincide con la arquitectura revisada')
c=c.replace('./Semana 8/','./Semana 9/')
# Los Dockerfiles con COPY Semana 9/... necesitan el contexto de la RAIZ,
# no el directorio del microservicio. Evita builds rotos.
for nombre, carpeta in (
    ('bank-backend','bank-backend'),
    ('retiros-event-consumer','retiros-event-consumer'),
    ('bff-web','bff/bff-web'),
    ('bff-mobile','bff/bff-mobile'),
    ('bff-atm','bff/bff-atm'),
):
    viejo='  '+nombre+':\n    build:\n      context: "./Semana 9/'+carpeta+'"'
    nuevo='  '+nombre+':\n    build:\n      context: .\n      dockerfile: "Semana 9/'+carpeta+'/Dockerfile"'
    if viejo in c: c=c.replace(viejo,nuevo,1)
legacy='      - "./Semana 9/database/02_seed_processed_snapshot.sql:/docker-entrypoint-initdb.d/02_seed_processed_snapshot.sql:ro"\n'
if legacy in c: c=c.replace(legacy,'')
# Metadatos Batch y las tablas de los 3 microservicios nuevos se crean solo al
# inicializar una BD verdaderamente vacía. Volúmenes existentes NO se resetean.
addvol='''      - "./Semana 9/data/db/03_retiros_idempotencia.sql:/docker-entrypoint-initdb.d/03_retiros_idempotencia.sql:ro"
      - "./Semana 9/batch-service/src/main/resources/db/schema-spring-batch-postgresql.sql:/docker-entrypoint-initdb.d/04_batch_schema.sql:ro"
      - "./Semana 9/batch-service/src/main/resources/db/schema-registros-rechazados.sql:/docker-entrypoint-initdb.d/05_rechazados.sql:ro"
      - "./Semana 9/cuentas-service/src/main/resources/db/migration/V2__cuentas_gestion.sql:/docker-entrypoint-initdb.d/06_cuentas.sql:ro"
      - "./Semana 9/clientes-service/src/main/resources/schema.sql:/docker-entrypoint-initdb.d/07_clientes.sql:ro"
      - "./Semana 9/pagos-service/src/main/resources/schema.sql:/docker-entrypoint-initdb.d/08_pagos.sql:ro"
'''
basevol='      - "./Semana 9/database/01_schema.sql:/docker-entrypoint-initdb.d/01_schema.sql:ro"\n'
if '03_retiros_idempotencia.sql:/docker-entrypoint-initdb.d' not in c:
    if basevol not in c: raise RuntimeError('Volumen de esquema principal no encontrado en Compose')
    c=c.replace(basevol,basevol+addvol,1)
# Agregar los servicios requeridos por rúbrica, compartiendo POSTGRES_DB existente.
if '  pagos-service:' not in c:
    before='volumes:\n  bancoxyz_postgres_data:'
    if before not in c: raise RuntimeError('Sección volumes no encontrada para insertar servicios')
    extra='''  cuentas-service:
    build:
      context: .
      dockerfile: "Semana 9/cuentas-service/Dockerfile"
    restart: unless-stopped
    environment:
      CUENTAS_DB_URL: jdbc:postgresql://postgres:5432/${POSTGRES_DB:-bancoxyz}
      CUENTAS_DB_USER: ${POSTGRES_USER:-bancoxyz}
      CUENTAS_DB_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD requerido}
      CUENTAS_JWT_ISSUER_URI: ${OAUTH2_ISSUER_URI:?OAUTH2_ISSUER_URI requerido}
      EUREKA_URL: http://discovery-server:8761/eureka/
    depends_on:
      postgres:
        condition: service_healthy
      discovery-server:
        condition: service_healthy
      keycloak:
        condition: service_healthy
    networks:
      - bancoxyz-net

  clientes-service:
    build: "./Semana 9/clientes-service"
    restart: unless-stopped
    environment:
      CLIENTES_SERVICE_DB_URL: jdbc:postgresql://postgres:5432/${POSTGRES_DB:-bancoxyz}
      CLIENTES_SERVICE_DB_USER: ${POSTGRES_USER:-bancoxyz}
      CLIENTES_SERVICE_DB_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD requerido}
      CLIENTES_SERVICE_JWT_ISSUER_URI: ${OAUTH2_ISSUER_URI:?OAUTH2_ISSUER_URI requerido}
      CLIENTES_SERVICE_JWK_SET_URI: http://keycloak:8080/realms/bancoxyz/protocol/openid-connect/certs
      EUREKA_URL: http://discovery-server:8761/eureka/
    depends_on:
      postgres:
        condition: service_healthy
      discovery-server:
        condition: service_healthy
      keycloak:
        condition: service_healthy
    networks:
      - bancoxyz-net

  pagos-service:
    build: "./Semana 9/pagos-service"
    restart: unless-stopped
    environment:
      PAGOS_SERVICE_DB_URL: jdbc:postgresql://postgres:5432/${POSTGRES_DB:-bancoxyz}
      PAGOS_SERVICE_DB_USER: ${POSTGRES_USER:-bancoxyz}
      PAGOS_SERVICE_DB_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD requerido}
      PAGOS_SERVICE_JWT_ISSUER_URI: ${OAUTH2_ISSUER_URI:?OAUTH2_ISSUER_URI requerido}
      PAGOS_SERVICE_JWK_SET_URI: http://keycloak:8080/realms/bancoxyz/protocol/openid-connect/certs
      EUREKA_URL: http://discovery-server:8761/eureka/
    depends_on:
      postgres:
        condition: service_healthy
      discovery-server:
        condition: service_healthy
      keycloak:
        condition: service_healthy
    networks:
      - bancoxyz-net

'''
    c=c.replace(before,extra+before,1)
save(compose,c)
# G. Precondiciones para las referencias que quedaron con Semana 9.
for ref in ('Semana 9/database/01_schema.sql', 'Semana 9/keycloak/bancoxyz-realm.json',
            'Semana 9/config-repo', 'Semana 9/bff/bff-web',
            'Semana 9/bff/bff-mobile','Semana 9/bff/bff-atm'):
    if not (root/ref).exists(): raise RuntimeError('Falta recurso de Compose: '+ref)
# H. Fuente CSV: solo lectura, jamás sobrescribir ni eliminar.
csv=list((s9/'batch-service/src/main/resources/data').glob('*.csv'))
expected={'movimientos_financieros_diarios.csv','intereses_trimestrales.csv','estados_financieros_anuales.csv'}
if {x.name for x in csv}!=expected:
    raise RuntimeError('Los CSV fuente son distintos a la auditoría. No se aplican cambios.')
original={p:hashlib.sha256(p.read_bytes()).hexdigest() for p in csv}
# Todos los archivos preinspeccionados. Escribir sin backups extra.
for p,t in patches.items():
    p.parent.mkdir(parents=True,exist_ok=True)
    if p.exists() and p.read_text(encoding='utf-8')==t: continue
    fd,tmp=tempfile.mkstemp(prefix='.bancoxyz_tmp_',dir=p.parent)
    try:
        with os.fdopen(fd,'w',encoding='utf-8',newline='') as f: f.write(t)
        os.replace(tmp,p)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    print('APLICADO:',p.relative_to(root))
for p,h in original.items():
    if hashlib.sha256(p.read_bytes()).hexdigest()!=h: raise RuntimeError('CSV alterado: '+str(p))
print('OK: codigo, Compose y BD objetivo unificados. Los tres CSV permanecen intactos.')
print('AVISO: no se han migrado datos reales ni eliminado las BD previas.')
PYCODE
if command -v mvn >/dev/null 2>&1; then
    echo '== Compilando y probando las clases modificadas =='
    mvn -q -f 'Semana 9/shared-contracts/pom.xml' install -DskipTests
    mvn -q -f 'Semana 9/bank-backend/pom.xml' clean test
    mvn -q -f 'Semana 9/bff/bff-atm/pom.xml' clean test
    mvn -q -f 'Semana 9/batch-service/pom.xml' clean test
else
    echo 'AVISO: Maven no encontrado. Cambios aplicados sin compilacion.'
fi
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo '== Validando Docker Compose sin reiniciar contenedores =='
    docker compose config --quiet
else
    echo 'AVISO: Docker Compose no disponible. Configuracion pendiente de validar en el host.'
fi
printf '\nOK: BLOQUES 3+4 CODIGO/CONFIGURACION APLICADOS.\n'
printf 'SIGUIENTE: bash "Semana 9/scripts/aplicar_bloques_3_y_4.sh" --migrar (DDL aditivo, BD existente).\n'
fi

if [[ "$MODO" == '--migrar' ]]; then
    if ! command -v docker >/dev/null 2>&1; then echo 'ERROR: Docker requerido'; exit 4; fi
    if ! docker compose ps --status running --services | grep -qx postgres; then
        echo 'ERROR: PostgreSQL no esta funcionando. Ningun SQL ejecutado.'; exit 4
    fi
    echo '== Esquemas ADITIVOS sobre la unica BD de Compose: ni TRUNCATE ni DROP =='
    for sql in \
      'Semana 9/database/01_schema.sql' \
      'Semana 9/data/db/03_retiros_idempotencia.sql' \
      'Semana 9/batch-service/src/main/resources/db/schema-spring-batch-postgresql.sql' \
      'Semana 9/batch-service/src/main/resources/db/schema-registros-rechazados.sql' \
      'Semana 9/cuentas-service/src/main/resources/db/migration/V2__cuentas_gestion.sql' \
      'Semana 9/clientes-service/src/main/resources/schema.sql' \
      'Semana 9/pagos-service/src/main/resources/schema.sql'; do
        [[ -f "$sql" ]] || { echo "Falta SQL: $sql"; exit 4; }
        if grep -Ein '^\s*(DROP|TRUNCATE|DELETE|UPDATE|INSERT|ALTER)\b' "$sql"; then
           echo "ERROR: SQL no es solo de creacion: $sql"; exit 4
        fi
        echo "APLICANDO: $sql"
        docker compose exec -T postgres sh -c 'psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$sql"
    done
    echo 'OK: DDL idempotente aplicado. NO se cargaron CSV ni se borraron bases.'
fi
if [[ "$MODO" == '--cargar-csv' ]]; then
    # Solo se leen los CSV incluidos en batch-service/resources/data.
    # La ejecución es explícita porque escribe filas derivadas en la BD.
    command -v mvn >/dev/null 2>&1 || { echo 'ERROR: Maven requerido'; exit 4; }
    command -v docker >/dev/null 2>&1 || { echo 'ERROR: Docker requerido'; exit 4; }
    docker compose ps --status running --services | grep -qx postgres || {
       echo 'ERROR: no hay PostgreSQL activo. Ejecuta antes --migrar.'; exit 4;
    }
    # Variables .env declarativas, sin evaluar su contenido como comandos.
    # Las variables exportadas por el usuario tienen prioridad.
    eval "$(python3 - <<'PYENV'
from pathlib import Path
import shlex, os
p=Path('.env')
if p.is_file():
    for line in p.read_text().splitlines():
        line=line.strip()
        if not line or line.startswith('#') or '=' not in line: continue
        k,v=line.split('=',1); k=k.strip()
        if k not in ('POSTGRES_DB','POSTGRES_PORT','POSTGRES_USER','POSTGRES_PASSWORD'): continue
        if k in os.environ: continue
        # Nunca imprimir valores; comandos quedan internos de la sesión.
        print('export '+k+'='+shlex.quote(v.strip().strip('"').strip("'")))
PYENV
)"
    export BATCH_DB_URL="${BATCH_DB_URL:-jdbc:postgresql://127.0.0.1:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-bancoxyz}}"
    export BATCH_DB_USER="${BATCH_DB_USER:-${POSTGRES_USER:-bancoxyz}}"
    export BATCH_DB_PASSWORD="${BATCH_DB_PASSWORD:-${POSTGRES_PASSWORD:-}}"
    [[ -n "$BATCH_DB_PASSWORD" ]] || { echo 'ERROR: falta password PostgreSQL. No se ejecutaron Jobs.'; exit 4; }
    # Las 3 tablas se crearon con --migrar, no desde snapshot antiguo.
    tablas="$(docker compose exec -T postgres sh -c 'psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At' <<'SQL'
SELECT count(*) FROM information_schema.tables WHERE table_schema='public'
 AND table_name IN ('cuentas_intereses','transacciones_procesadas','estados_cuenta_anuales','batch_job_instance');
SQL
)"
    [[ "$tablas" == '4' ]] || { echo "ERROR: faltan tablas base o metadatos Batch ($tablas/4). Ejecuta --migrar primero."; exit 4; }
    for csv in movimientos_financieros_diarios.csv intereses_trimestrales.csv estados_financieros_anuales.csv; do
       [[ -s "Semana 9/batch-service/src/main/resources/data/$csv" ]] || { echo "ERROR: falta fuente CSV: $csv"; exit 4; }
    done
    RUN_ID="$(date +%s%N)"
    for job in transaccionJob cuentaInteresJob estadoCuentaAnualJob; do
        echo "== Procesando $job desde los CSV de Semana 9 =="
        mvn -B -q -f 'Semana 9/batch-service/pom.xml' spring-boot:run \
          "-Dspring-boot.run.arguments=--app.batch.job=$job --app.batch.run-id=$RUN_ID"
        RUN_ID="$((RUN_ID+1))"
    done
    echo 'OK: tres Jobs Batch completados en la BD configurada. Fuentes CSV intactas.'
    echo 'IMPORTANTE: vuelve a ejecutar --validar; no se eliminan bases antiguas ni snapshot.'
fi
if [[ "$MODO" == '--validar' ]]; then
    python3 - "$BASE" <<'PYCODE'
import sys, pathlib, hashlib, re
r=pathlib.Path(sys.argv[1]); s=r/'Semana 9'
for n in ('movimientos_financieros_diarios.csv','intereses_trimestrales.csv','estados_financieros_anuales.csv'):
 p=s/'batch-service/src/main/resources/data'/n
 if not p.is_file(): raise SystemExit('ERROR: falta CSV '+n)
 print('CSV FUENTE:',n,'bytes=',p.stat().st_size,'SHA256=',hashlib.sha256(p.read_bytes()).hexdigest())
c=(r/'docker-compose.yml').read_text()
assert './Semana 8/' not in c, 'Compose todavía usa Semana 8'
assert '02_seed_processed_snapshot.sql' not in c, 'Compose todavía carga snapshot antiguo'
assert len(re.findall(r'^  postgres:$', c, re.M)) == 1, 'Compose declara múltiples postgres'
for n in ('cuentas-service','clientes-service','pagos-service'):
 assert '  '+n+':' in c, 'Falta servicio '+n
print('OK: una sola instancia PostgreSQL declarada, Semana 9, sin snapshot legado enlazado.')
PYCODE
    if command -v docker >/dev/null 2>&1 && docker compose ps --status running --services 2>/dev/null | grep -qx postgres; then
        echo '== Tablas existentes (solo lectura) =='
        docker compose exec -T postgres sh -c 'psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At' <<'SQL'
SELECT table_name FROM information_schema.tables WHERE table_schema='public'
AND table_name IN ('cuentas_intereses','estados_cuenta_anuales','transacciones_procesadas','resumen_transacciones_diarias','retiros_idempotencia','pagos_solicitudes','cuentas_gestion','clientes_perfil')
ORDER BY table_name;
SQL
    fi
fi
