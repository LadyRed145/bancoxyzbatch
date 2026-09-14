# Evidencias — Semana 5

Colocar aquí la documentación final de evidencias de la actividad sumativa:

```text
BancoXYZ_BFF_Evidencias_Semana5.pdf
```

La evidencia recomendada debe incluir:

1. `./mvnw clean compile` con `BUILD SUCCESS`.
2. Bank Backend activo en 8080.
3. BFF Web HTTPS en 8081.
4. BFF Mobile HTTPS en 8082.
5. BFF ATM HTTPS en 8083.
6. Endpoints personalizados Web/Mobile/ATM.
7. Comparación de payloads y tiempos.
8. Certificados HTTPS de los tres BFF.
9. `401` sin token o con token desconocido.
10. `403` al usar un rol de otro canal.
11. Retiro inválido con `400`.
12. Retiro real controlado con saldo antes/después y limpieza del fixture.
13. Estructura `controller/service/client/mapper/dto/exception/config`.
14. Configuración `backend.timeout` y explicación de `503/504` para servicios no disponibles o lentos.
