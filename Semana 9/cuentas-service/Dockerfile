FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY ["pom.xml", "/workspace/pom.xml"]
COPY ["Semana 9/cuentas-service/", "/workspace/Semana 9/cuentas-service/"]
RUN mvn -B -f "Semana 9/cuentas-service/pom.xml" -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build ["/workspace/Semana 9/cuentas-service/target/*.jar", "/app/app.jar"]
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
