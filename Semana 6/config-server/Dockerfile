FROM maven:3.9-eclipse-temurin-21-noble AS build

WORKDIR /workspace

COPY pom.xml .
COPY src ./src

RUN mvn -B -DskipTests clean package

FROM eclipse-temurin:21-jre-noble

RUN apt-get update \ 
    && apt-get install -y --no-install-recommends curl \ 
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /workspace/target/*.jar /app/app.jar

EXPOSE 8888

ENTRYPOINT ["java","-jar","/app/app.jar"]
