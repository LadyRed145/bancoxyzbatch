# Contexto Docker: raíz del proyecto, definido en docker-compose.yml.
# Copiar solo la biblioteca requerida y este servicio evita arrastrar secretos.
FROM maven:3.9-eclipse-temurin-21-noble AS build
WORKDIR /workspace

COPY ["Semana 9/shared-contracts/", "/workspace/shared-contracts/"]
COPY ["Semana 9/bank-backend/", "/workspace/bank-backend/"]

# Ambas compilaciones ocurren DENTRO de la misma imagen de construcción.
RUN mvn -B -f /workspace/shared-contracts/pom.xml -DskipTests install \
    && mvn -B -f /workspace/bank-backend/pom.xml -DskipTests clean package

FROM eclipse-temurin:21-jre-noble

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /workspace/bank-backend/target/*.jar /app/app.jar

EXPOSE 8080

ENTRYPOINT ["java","-jar","/app/app.jar"]
