# Contexto Docker: raíz del proyecto, definido en docker-compose.yml.
# Copiar solo la biblioteca requerida y este servicio evita arrastrar secretos.
FROM maven:3.9-eclipse-temurin-21-noble AS build
WORKDIR /workspace

COPY ["Semana 9/shared-resilience/", "/workspace/shared-resilience/"]
COPY ["Semana 9/bff/bff-atm/", "/workspace/bff-atm/"]

# Ambas compilaciones ocurren DENTRO de la misma imagen de construcción.
RUN mvn -B -f /workspace/shared-resilience/pom.xml -DskipTests install \
    && mvn -B -f /workspace/bff-atm/pom.xml -DskipTests clean package

FROM eclipse-temurin:21-jre-noble

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /workspace/bff-atm/target/*.jar /app/app.jar

EXPOSE 8083

ENTRYPOINT ["java","-jar","/app/app.jar"]
