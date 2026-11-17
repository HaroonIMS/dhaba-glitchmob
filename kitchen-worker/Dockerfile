FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml checkstyle.xml ./
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B package -DskipTests -Dcheckstyle.skip=true

FROM eclipse-temurin:21-jre-alpine
RUN adduser -D -u 10001 app
COPY --from=build /src/target/kitchen-worker.jar /app.jar
ARG GIT_COMMIT=dev
ENV GIT_COMMIT=${GIT_COMMIT}
USER app
# No web port: the worker touches /tmp/heartbeat every 10s, after Redis accepted its heartbeat.
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD [ -f /tmp/heartbeat ] && [ $(( $(date +%s) - $(stat -c %Y /tmp/heartbeat) )) -lt 60 ] || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app.jar"]
