# Backend (Spring Boot). Build em duas etapas: a imagem final so tem JRE + jar, sem codigo-fonte.
FROM eclipse-temurin:25-jdk AS build
WORKDIR /src
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN chmod +x mvnw && ./mvnw -q -B dependency:go-offline
COPY src src
RUN ./mvnw -q -B -DskipTests package

FROM eclipse-temurin:25-jre
RUN useradd --system --uid 10001 --no-create-home app
WORKDIR /app
COPY --from=build /src/target/gymmanager-*.jar /app/app.jar
USER app
EXPOSE 8080
ENV SPRING_PROFILES_ACTIVE=prod
# a API grava horarios sem fuso (LocalDateTime): o fuso do container passa a ser o fuso do sistema.
# Sem isso a JVM roda em UTC e o app (que le como hora local) desloca dias, cronometro e limite diario da IA.
ENV TZ=America/Sao_Paulo
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
