#!/usr/bin/env fish

# Tokens académicos. Si existen variables de entorno, las uso para no depender de valores hardcodeados.
set WEB_TOKEN (set -q WEB_API_TOKEN; and echo $WEB_API_TOKEN; or echo 'bancoxyz-web-demo-token-2026')
set MOBILE_TOKEN (set -q MOBILE_API_TOKEN; and echo $MOBILE_API_TOKEN; or echo 'bancoxyz-mobile-demo-token-2026')
set ATM_TOKEN (set -q ATM_API_TOKEN; and echo $ATM_API_TOKEN; or echo 'bancoxyz-atm-demo-token-2026')
set UNKNOWN_TOKEN 'token-desconocido-para-prueba'
set -g FALLAS 0

function registrar_falla
    set -g FALLAS (math $FALLAS + 1)
    echo 'RESULTADO: FALLÓ'
end

function registrar_ok
    echo 'RESULTADO: OK'
end

function prueba_json
    set titulo $argv[1]
    set token $argv[2]
    set url $argv[3]
    set esperado $argv[4]
    set archivo $argv[5]

    echo "\n=== $titulo ==="

    set metricas (curl -ksS \
        -H "Authorization: Bearer $token" \
        -o $archivo \
        -w '%{http_code}|%{size_download}|%{time_total}' \
        $url)

    set partes (string split '|' $metricas)
    set codigo $partes[1]

    echo "HTTP $codigo | bytes $partes[2] | tiempo $partes[3]s | esperado $esperado"
    jq . $archivo 2>/dev/null; or cat $archivo

    if test "$codigo" = "$esperado"
        registrar_ok
    else
        registrar_falla
    end
end

function prueba_codigo
    set titulo $argv[1]
    set esperado $argv[2]
    set token $argv[3]
    set url $argv[4]

    echo "\n=== $titulo ==="

    if test "$token" = '-'
        set codigo (curl -ksS -o /dev/null -w '%{http_code}' $url)
    else
        set codigo (curl -ksS \
            -H "Authorization: Bearer $token" \
            -o /dev/null \
            -w '%{http_code}' \
            $url)
    end

    echo "HTTP $codigo | esperado $esperado"

    if test "$codigo" = "$esperado"
        registrar_ok
    else
        registrar_falla
    end
end

function mostrar_certificado
    set titulo $argv[1]
    set puerto $argv[2]

    echo "\n=== HTTPS - $titulo ==="

    if command -q openssl
        echo | openssl s_client \
            -connect localhost:$puerto \
            -servername localhost \
            2>/dev/null | openssl x509 -noout -subject -issuer -dates
    else
        echo 'openssl no está disponible; omito el detalle del certificado.'
    end
end

function prueba_retiro_invalido
    echo '\n=== ATM - retiro inválido seguro (0.50) debe ser 400 ==='

    set archivo /tmp/bff_retiro_invalido.json
    set metricas (curl -ksS \
        -H "Authorization: Bearer $ATM_TOKEN" \
        -H 'Content-Type: application/json' \
        -d '{"monto":0.50}' \
        -o $archivo \
        -w '%{http_code}|%{size_download}|%{time_total}' \
        https://localhost:8083/api/atm/cuentas/101/retiro)

    set partes (string split '|' $metricas)
    set codigo $partes[1]

    echo "HTTP $codigo | bytes $partes[2] | tiempo $partes[3]s | esperado 400"
    jq . $archivo 2>/dev/null; or cat $archivo

    if test "$codigo" = '400'
        registrar_ok
    else
        registrar_falla
    end
end

echo 'BancoXYZ - verificación BFF Semana 5'
echo 'Pruebo funcionalidad, optimización, HTTPS, autenticación y autorización sin modificar saldos reales.'

# Funcionalidad y adaptación de payload por canal.
prueba_json 'WEB - cuentas completas' $WEB_TOKEN https://localhost:8081/api/web/cuentas 200 /tmp/bff_web_cuentas.json
prueba_json 'WEB - detalle agregado' $WEB_TOKEN https://localhost:8081/api/web/cuentas/101/detalle 200 /tmp/bff_web_detalle.json
prueba_json 'MOBILE - cuentas resumidas' $MOBILE_TOKEN https://localhost:8082/api/mobile/cuentas 200 /tmp/bff_mobile_cuentas.json
prueba_json 'MOBILE - resumen individual' $MOBILE_TOKEN https://localhost:8082/api/mobile/cuentas/101/resumen 200 /tmp/bff_mobile_resumen.json
prueba_json 'ATM - saldo mínimo' $ATM_TOKEN https://localhost:8083/api/atm/cuentas/101/saldo 200 /tmp/bff_atm_saldo.json

# HTTPS/certificados de los tres BFF.
mostrar_certificado 'BFF Web :8081' 8081
mostrar_certificado 'BFF Mobile :8082' 8082
mostrar_certificado 'BFF ATM :8083' 8083

# Distingo autenticación de autorización: token ausente/desconocido => 401; token válido de otro rol => 403.
prueba_codigo 'SEGURIDAD - ATM sin token' 401 - https://localhost:8083/api/atm/cuentas/101/saldo
prueba_codigo 'SEGURIDAD - token desconocido en Web' 401 $UNKNOWN_TOKEN https://localhost:8081/api/web/cuentas
prueba_codigo 'AUTORIZACIÓN - token WEB intentando usar Mobile' 403 $WEB_TOKEN https://localhost:8082/api/mobile/cuentas
prueba_codigo 'AUTORIZACIÓN - token MOBILE intentando usar ATM' 403 $MOBILE_TOKEN https://localhost:8083/api/atm/cuentas/101/saldo
prueba_codigo 'AUTORIZACIÓN - token ATM intentando usar Web' 403 $ATM_TOKEN https://localhost:8081/api/web/cuentas

# Validación de borde: esta solicitud no puede modificar la base porque el monto es inferior al mínimo permitido.
prueba_retiro_invalido

echo '\n========================================'
if test $FALLAS -eq 0
    echo 'VERIFICACIÓN FINAL: TODAS LAS PRUEBAS PASARON'
    exit 0
else
    echo "VERIFICACIÓN FINAL: $FALLAS PRUEBA(S) FALLARON"
    exit 1
end
