#!/usr/bin/env bash
# BancoXYZ S9 - auditoria TLS/Kafka + prueba HTTP real de Pagos con JWT.
# Compatible con Fish al invocarse mediante bash. No modifica CSV ni ejecuta Batch.
set -Eeuo pipefail
if [[ -f 'Semana 9/pagos-service/pom.xml' && -f docker-compose.yml ]]; then
  :
else
  cd -- "$(dirname -- "$(dirname -- "$(dirname -- "$(realpath -- "$0")")")")"
fi
python3 - "$@" <<'PY'
import concurrent.futures
import datetime
import json
import os
import re
import socket
import ssl
import subprocess
import sys
import urllib.parse
import urllib.request
import uuid
from decimal import Decimal
from pathlib import Path

LAB = '--laboratorio' in sys.argv[1:]
VALID = {'--auditar', '--laboratorio', '--exigir-tls-publico'}
if any(a not in VALID for a in sys.argv[1:]):
    raise SystemExit('Uso: bash verificar_pagos_tls_kafka_s9.sh [--auditar | --laboratorio] [--exigir-tls-publico]')
REQUIRE_PUBLIC = '--exigir-tls-publico' in sys.argv[1:]
ROOT = Path.cwd()
CSV = ROOT/'Semana 9/batch-service/src/main/resources/data'
CSV_NAMES = ('movimientos_financieros_diarios.csv','intereses_trimestrales.csv','estados_financieros_anuales.csv')
FAIL = []
WARN = []

def good(msg): print('[OK] '+msg, flush=True)
def warn(msg): WARN.append(msg); print('[AVISO] '+msg, flush=True)
def fail(msg): FAIL.append(msg); print('[FALLO] '+msg, flush=True)
def run(cmd, inp=None, timeout=45, check=True):
    result = subprocess.run(cmd, input=inp, text=True, capture_output=True, timeout=timeout)
    if check and result.returncode:
        tail = ((result.stderr or '') + '\n' + (result.stdout or ''))[-850:]
        raise RuntimeError('Fallo al ejecutar '+ ' '.join(cmd[:5]) + ': '+tail)
    return result

def compose(*args, inp=None, timeout=45, check=True):
    return run(['docker','compose',*args],inp,timeout,check)

def pg(sql):
    return compose('exec','-T','postgres','sh','-c',
                   'exec psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"',
                   inp=sql+'\n',timeout=40).stdout.strip()

def pg_one(sql):
    lines=[x for x in pg(sql).splitlines() if x.strip()]
    if len(lines)!=1: raise RuntimeError(f'Consulta devolvio {len(lines)} filas en vez de 1')
    return lines[0]

def service_health(name):
    cid=compose('ps','-q',name,check=False).stdout.strip()
    if not cid: return 'NO_INICIADO'
    return run(['docker','inspect','-f','{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}',cid]).stdout.strip()

def config():
    obj=compose('config','--format','json').stdout
    return json.loads(obj)

def tls_local(port):
    ctx=ssl._create_unverified_context()
    with socket.create_connection(('127.0.0.1',port),timeout=5) as sock:
        with ctx.wrap_socket(sock,server_hostname='localhost') as s:
            return s.version(),s.cipher()[0]

def tls_public(domain):
    ctx=ssl.create_default_context()
    with socket.create_connection((domain,443),timeout=8) as sock:
        with ctx.wrap_socket(sock,server_hostname=domain) as s:
            cert=s.getpeercert()
            expires=datetime.datetime.fromtimestamp(ssl.cert_time_to_seconds(cert['notAfter']),datetime.timezone.utc)
            if expires<=datetime.datetime.now(datetime.timezone.utc):
                raise RuntimeError('Certificado vencido')
            return s.version(),expires.strftime('%Y-%m-%d')

def curl_q(x):
    return '"'+str(x).replace('\\','\\\\').replace('"','\\"').replace('\n','\\n')+'"'

def api(token, method, path, body=None, key=None):
    # Curl recibe el JWT via stdin (no aparece en argv ni en el historial).
    cfg=['url = '+curl_q('http://127.0.0.1:8080'+path),
         'request = '+curl_q(method),
         'header = '+curl_q('Authorization: Bearer '+token),
         'header = '+curl_q('Accept: application/json'),
         'connect-timeout = 6', 'max-time = 25']
    if key: cfg.append('header = '+curl_q('Idempotency-Key: '+str(key)))
    if body is not None:
        cfg.append('header = '+curl_q('Content-Type: application/json'))
        cfg.append('data = '+curl_q(json.dumps(body,ensure_ascii=True,separators=(',',':'))))
    p=compose('exec','-T','pagos-service','curl','--silent','--show-error',
              '--write-out','\n__CODE__:%{http_code}','--config','-',
              inp='\n'.join(cfg)+'\n',timeout=40,check=False)
    if p.returncode!=0: raise RuntimeError('Fallo HTTP interno de Pagos: '+(p.stderr or '')[-300:])
    m=re.search(r'\n__CODE__:(\d{3})\s*$',p.stdout)
    if not m: raise RuntimeError('Respuesta sin codigo HTTP: '+p.stdout[-250:])
    raw=p.stdout[:m.start()].strip()
    try: data=json.loads(raw)
    except (ValueError,TypeError): data={'raw':raw[:350]}
    return int(m.group(1)),data

def jwt():
    # Permite token suministrado, o lo emite desde el cliente Web configurado en Keycloak.
    if os.getenv('BANCOXYZ_JWT'): return os.environ['BANCOXYZ_JWT'].strip()
    if os.getenv('BANCOXYZ_JWT_FILE'):
        return Path(os.environ['BANCOXYZ_JWT_FILE']).read_text().strip()
    env=CFG.get('services',{}).get('keycloak',{}).get('environment',{})
    if isinstance(env,list): env=dict(x.split('=',1) for x in env if '=' in x)
    secret=env.get('OAUTH2_WEB_CLIENT_SECRET')
    if not secret or secret.startswith('${') or secret == 'CHANGE_ME':
        raise RuntimeError('Sin secreto OAuth2 configurado. Usa BANCOXYZ_JWT_FILE con un JWT valido.')
    port=compose('port','keycloak','8080').stdout.strip().rsplit(':',1)[-1]
    if not port.isdigit(): raise RuntimeError('No se detecto puerto de Keycloak; use BANCOXYZ_JWT_FILE.')
    url=os.getenv('BANCOXYZ_TOKEN_URL', f'http://127.0.0.1:{port}/realms/bancoxyz/protocol/openid-connect/token')
    dat=urllib.parse.urlencode({'grant_type':'client_credentials','client_id':'bff-web-client',
                                'client_secret':secret}).encode()
    req=urllib.request.Request(url,data=dat,headers={'Content-Type':'application/x-www-form-urlencoded'})
    try:
        with urllib.request.urlopen(req,timeout=12) as reply: tok=json.load(reply)['access_token']
    except Exception as e:
        raise RuntimeError('No se pudo obtener JWT del cliente Web: '+str(e)[:150]+'. Alternativa: BANCOXYZ_JWT_FILE.')
    # Keycloak firma el JWT; la validacion criptografica la realiza pagos-service.
    return tok

def create_fixture():
    sql="""
    BEGIN;
    INSERT INTO cuentas_gestion(titular,tipo,estado,saldo_inicial)
    SELECT '__EFT_S9_PAGOS_QA_ORIGEN__','CORRIENTE','ACTIVA',1000.00
    WHERE NOT EXISTS(SELECT 1 FROM cuentas_gestion WHERE titular='__EFT_S9_PAGOS_QA_ORIGEN__');
    INSERT INTO cuentas_gestion(titular,tipo,estado,saldo_inicial)
    SELECT '__EFT_S9_PAGOS_QA_DESTINO__','CORRIENTE','ACTIVA',500.00
    WHERE NOT EXISTS(SELECT 1 FROM cuentas_gestion WHERE titular='__EFT_S9_PAGOS_QA_DESTINO__');
    COMMIT;
    SELECT id||'|'||saldo_inicial||'|'||estado FROM cuentas_gestion
    WHERE titular='__EFT_S9_PAGOS_QA_ORIGEN__';
    SELECT id||'|'||saldo_inicial||'|'||estado FROM cuentas_gestion
    WHERE titular='__EFT_S9_PAGOS_QA_DESTINO__';
    """
    lines=[x for x in pg(sql).splitlines() if '|' in x]
    if len(lines)!=2: raise RuntimeError('Fixture no es unica; revisar cuentas con titular QA antes de seguir')
    a,b=[x.split('|') for x in lines]
    if (Decimal(a[1]),a[2],Decimal(b[1]),b[2])!=(Decimal('1000.00'),'ACTIVA',Decimal('500.00'),'ACTIVA'):
        raise RuntimeError('Fixture QA cambiada o cerrada; no se realizan operaciones')
    return int(a[0]),int(b[0])

def idkey(label): return uuid.uuid5(uuid.NAMESPACE_URL,'bancoxyz:eft-s9:pagos:qa:v1:'+label)

def snapshot(ids):
    a,b=ids
    sql=f"""
    SELECT 'a|'||COALESCE((SELECT saldo_actual::text FROM pagos_saldos WHERE cuenta_id={a}),'SIN_INICIALIZAR');
    SELECT 'b|'||COALESCE((SELECT saldo_actual::text FROM pagos_saldos WHERE cuenta_id={b}),'SIN_INICIALIZAR');
    SELECT 'mov|'||count(*) FROM pagos_movimientos WHERE cuenta_id IN ({a},{b});
    SELECT 'extra|'||count(*) FROM pagos_solicitudes
     WHERE (origen IN ({a},{b}) OR destino IN ({a},{b}))
       AND id NOT IN ('{idkey('transferencia')}','{idkey('pago')}','{idkey('deposito')}','{idkey('concurrente')}');
    SELECT 'keys|'||count(*) FROM pagos_solicitudes
     WHERE id IN ('{idkey('transferencia')}','{idkey('pago')}','{idkey('deposito')}','{idkey('concurrente')}')
       AND estado='APLICADO';
    """
    try: return dict(x.split('|',1) for x in pg(sql).splitlines() if '|' in x)
    except Exception as e: raise RuntimeError('Lectura del ledger fallo: '+str(e)[:250])

def assert_snapshot(s):
    if s.get('extra')!='0': raise RuntimeError('Hay operaciones ajenas sobre las cuentas QA: ABORTAR')
    if s.get('keys')!='4': raise RuntimeError('No hay exactamente cuatro operaciones QA APLICADO')
    if s.get('mov')!='7': raise RuntimeError('El ledger de QA no contiene exactamente 7 movimientos')
    if Decimal(s.get('a','-1'))!=Decimal('997.25') or Decimal(s.get('b','-1'))!=Decimal('522.75'):
        raise RuntimeError('Saldos distintos de lo esperado: '+repr(s))

def request_ok(token,label,kind,src,dst,amount):
    body={'tipo':kind,'origen':src,'destino':dst,'monto':amount}
    key=idkey(label)
    status, data=api(token,'POST','/api/pagos/solicitudes',body,key)
    if status!=200 or data.get('estado')!='APLICADO' or data.get('id')!=str(key):
        raise RuntimeError(f'HTTP pago {label} NO aplicado: {status} {data}')
    return body

print('======== BANCOXYZ S9 · VERIFICACION TLS/KAFKA/PAGOS ========',flush=True)
if not (ROOT/'docker-compose.yml').is_file(): raise SystemExit('ERROR: ejecutar desde la raiz del repositorio BancoXYZ')
if not all((CSV/f).is_file() for f in CSV_NAMES): raise SystemExit('ERROR: faltan los 3 CSV originales')
import hashlib
before={n:hashlib.sha256((CSV/n).read_bytes()).hexdigest() for n in CSV_NAMES}
CFG=config()

print('\n== TLS de BFF y TLS publico ==',flush=True)
for name,port in [('web',8081),('mobile',8082),('atm',8083)]:
    try:
        ver,cipher=tls_local(port)
        good(f'BFF {name}: handshake TLS {ver} cifrado ({cipher}); confianza publica no demostrada')
    except Exception as e:
        warn(f'BFF {name} TLS local no comprobado en :{port}: {str(e)[:115]}')

caddy_cfg=CFG.get('services',{}).get('caddy',{})
ce=caddy_cfg.get('environment',{})
if isinstance(ce,list): ce=dict(x.split('=',1) for x in ce if '=' in x)
domain=os.getenv('PUBLIC_TLS_DOMAIN', ce.get('KEYCLOAK_DOMAIN',''))
domain=domain.replace('https://','').replace('http://','').split('/')[0].split(':')[0].strip()
if domain and '.' in domain and domain.lower() not in ('localhost','example.com') and not domain.endswith('.example.com'):
    try:
        ver,expiry=tls_public(domain)
        good(f'TLS PUBLICO VERIFICADO: https://{domain} {ver}, CA confiable, SAN correcto, expira {expiry}')
        try:
            with urllib.request.urlopen(f'https://{domain}/realms/bancoxyz/.well-known/openid-configuration',timeout=8) as reply:
                if reply.status==200:good('Keycloak publico por HTTPS: HTTP 200')
                else:warn(f'Keycloak publico HTTP {reply.status}')
        except Exception as e: warn('TLS publico valido, pero Keycloak no responde correctamente: '+str(e)[:125])
    except Exception as e:
        msg='TLS PUBLICO NO VALIDADO para '+domain+': '+str(e)[:150]
        fail(msg) if REQUIRE_PUBLIC else warn(msg)
else:
    msg='No hay dominio publico configurado para verificar certificado de Caddy (PUBLIC_TLS_DOMAIN).'
    fail(msg) if REQUIRE_PUBLIC else warn(msg)
try: print('Caddy (perfil EC2):',service_health('caddy'),flush=True)
except Exception: warn('Caddy no se pudo inspeccionar')

print('\n== Kafka multi-broker, cifrado y monitoreo ==',flush=True)
services=CFG.get('services',{})
for k in ['kafka-1','kafka-2','kafka-3']:
    env=services.get(k,{}).get('environment',{})
    if isinstance(env,list): env=dict(x.split('=',1) for x in env if '=' in x)
    proto=env.get('KAFKA_LISTENER_SECURITY_PROTOCOL_MAP','(sin listener)')
    good(f'{k}: configurado con {proto}') if proto else warn(k+' sin listeners')
if any('PLAINTEXT' in str(services.get(k,{}).get('environment',{})) for k in ['kafka-1','kafka-2','kafka-3']):
    warn('Kafka interno usa PLAINTEXT: no tiene TLS/SASL activo en los brokers actuales.')
warn('Los 3 brokers comparten el mismo host Docker; eso NO constituye multi-AZ.')
if 'kafka-ui' in services: good('Kafka UI presente (visualizacion operativa, no observabilidad centralizada completa).')
if not any('prometheus' in k.lower() or 'grafana' in k.lower() for k in services):
    warn('Compose sin Prometheus/Grafana: no hay monitoreo centralizado de metricas Kafka configurado.')
try:
    check=compose('exec','-T','kafka-1','/opt/kafka/bin/kafka-topics.sh','--bootstrap-server','localhost:19092',
                  '--describe','--topic','bancoxyz.retiros',timeout=22,check=False)
    if check.returncode==0:
        sample=[l.strip() for l in check.stdout.splitlines() if 'ReplicationFactor' in l or 'Replicas:' in l]
        good('Kafka topic observado en vivo: '+'; '.join(sample[:2])[:220])
    else: warn('No se pudo comprobar topic Kafka en vivo; revisar brokers encendidos.')
except Exception as e: warn('Comprobacion Kafka en vivo no disponible: '+str(e)[:125])

print('\n== Pagos JWT, idempotencia, persistencia ==',flush=True)
try:
    ph=service_health('pagos-service')
    if ph=='healthy':good('pagos-service HEALTHY')
    else:fail('pagos-service no saludable: '+ph)
except Exception as e: fail('No se pudo consultar Pagos: '+str(e)[:120])

if LAB and not FAIL:
    try:
        token=jwt()
        status,_=api('TOKEN_FICTICIO','GET','/api/pagos/solicitudes/'+str(idkey('no_existe')))
        if status==401: good('Seguridad: JWT invalido rechazado con HTTP 401')
        else: raise RuntimeError('JWT invalido no rechazo HTTP 401: '+str(status))
        ids=create_fixture()
        good(f'Cuentas QA aisladas: {ids[0]} y {ids[1]} (no son CSV ni cuentas reales).')
        initial=snapshot(ids)
        if initial.get('extra')!='0': raise RuntimeError('Operaciones externas en cuentas QA; abortando.')
        a,b=ids
        requests=[('transferencia','TRANSFERENCIA',a,b,'12.50'),
                  ('pago','PAGO',a,b,'7.25'),
                  ('deposito','DEPOSITO',999999,a,'20.00')]
        for label,kind,src,dst,amount in requests:
            body=request_ok(token,label,kind,src,dst,amount)
            good(f'{kind}: HTTP 200 / APLICADO persistente.')
            body2=request_ok(token,label,kind,src,dst,amount)
            good(f'{kind}: misma UUID reutilizada => misma respuesta, sin crear nueva solicitud.')
        # Una clave reusada con cuerpo diferente debe producir 409.
        wrong={'tipo':'TRANSFERENCIA','origen':a,'destino':b,'monto':'22.50'}
        st,_=api(token,'POST','/api/pagos/solicitudes',wrong,idkey('transferencia'))
        if st!=409: raise RuntimeError('Idempotency-Key con payload diferente NO devolvio 409: '+str(st))
        good('Clave reutilizada con cuerpo diferente => HTTP 409.')
        # Dos peticiones simultaneas de la misma UUID.  Debe aplicar exactamente una vez.
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures=[pool.submit(request_ok,token,'concurrente','TRANSFERENCIA',a,b,'3.00') for _ in range(2)]
            for future in futures: future.result(timeout=45)
        good('Concurrencia: dos transferencias simultaneas con la misma UUID => una liquidacion.')
        s=snapshot(ids)
        assert_snapshot(s)
        good('PostgreSQL: 4 solicitudes APLICADO, 7 movimientos unicos, saldos exactos 997.25 / 522.75.')
        # Reiniciar solo Pagos, SIN recrear contenedor, base ni volumen.
        compose('restart','pagos-service',timeout=40)
        healthy=False
        import time
        for i in range(25):
            if service_health('pagos-service')=='healthy': healthy=True;break
            time.sleep(2)
        if not healthy: raise RuntimeError('pagos-service no recupero HEALTHY despues de restart')
        good('pagos-service reiniciado y HEALTHY nuevamente.')
        token=jwt()   # volver a pedir credencial por posible expiracion
        s2=snapshot(ids)
        assert_snapshot(s2)
        if s2!=s: raise RuntimeError('Cambio inesperado de ledger despues del reinicio: '+repr(s2))
        for label,kind,src,dst,amount in requests+[('concurrente','TRANSFERENCIA',a,b,'3.00')]:
            body=request_ok(token,label,kind,src,dst,amount)
            st,data=api(token,'GET','/api/pagos/solicitudes/'+str(idkey(label)))
            if st!=200 or data.get('estado')!='APLICADO':
                raise RuntimeError('Solicitud no persistente: '+label)
        if snapshot(ids)!=s: raise RuntimeError('Una reejecucion despues de restart duplico dinero')
        good('PERSISTENCIA REAL: cuentas y 4 solicitudes sobreviven al reinicio; repetir las 4 UUID no duplica movimientos.')
        st,data=api(token,'GET',f'/api/pagos/cuentas/{a}/saldo')
        if st!=200 or Decimal(str(data.get('saldoActual','-1')))!=Decimal('997.25'):
            raise RuntimeError('Saldo HTTP no corresponde a PostgreSQL: '+repr(data))
        good('Saldo HTTP del origen coincide con el saldo persistido en PostgreSQL.')
    except Exception as e:
        fail('PRUEBA FUNCIONAL PAGOS: '+str(e)[:450])
else:
    if LAB: warn('No se realizaron transacciones de laboratorio porque el servicio ya tenia fallos.')
    else: warn('Modo lectura: use --laboratorio para probar JWT, transferencias reales QA, idempotencia y reinicio.')

import hashlib
for filename in CSV_NAMES:
    if hashlib.sha256((CSV/filename).read_bytes()).hexdigest()==before[filename]:
        good('CSV intacto: '+filename)
    else: fail('CSV MODIFICADO: '+filename)
print('\n======== RESULTADO ========',flush=True)
print(f'Fallos={len(FAIL)} | Avisos={len(WARN)} | Modo={"LABORATORIO" if LAB else "LECTURA"}')
print('Sin DROP, TRUNCATE, borrado de volumen, ni jobs Batch. Las cuentas QA son persistentes e idempotentes.')
if FAIL: sys.exit(1)
print('OK: verificaciones ejecutadas sin fallos. Los AVISOS no equivalen a funcionalidades certificadas.')
PY
