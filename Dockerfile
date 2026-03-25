# =========================
# Stage 1: Build
# =========================
FROM maven:3.9.6-eclipse-temurin-17 AS build

WORKDIR /build

# Copiamos primero dependencias (mejora cache)
COPY pom.xml .
RUN mvn -B -e -q dependency:go-offline

# Copiamos el código
COPY src ./src

# Compilamos
RUN mvn -B clean package -DskipTests


# =========================
# Stage 2: Runtime
# =========================
FROM eclipse-temurin:17-jre-alpine

ENV JAVA_OPTS="-Xms256m -Xmx512m"
WORKDIR /app

# Copiamos solo el JAR final
COPY --from=build /build/target/*.jar app.jar

EXPOSE 8080

# Usuario no root (seguridad)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

ENTRYPOINT ["sh","-c","java $JAVA_OPTS -jar app.jar"]
