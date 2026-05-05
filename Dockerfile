# syntax=docker/dockerfile:1

FROM bellsoft/liberica-openjdk-alpine-musl:17.0.19-11@sha256:4650dc9a56921824d3fdc1a9a95e3f9326a03a8fea0e2d2c590b5cc44fdb706f AS build

WORKDIR /workspace

COPY mvnw pom.xml ./
COPY .mvn .mvn

RUN chmod +x mvnw
RUN --mount=type=cache,target=/root/.m2 ./mvnw dependency:go-offline -B

COPY src src

RUN --mount=type=cache,target=/root/.m2 ./mvnw clean package -DskipTests


FROM bellsoft/liberica-openjre-alpine-musl:17.0.19-11@sha256:4abefe339e2a7d1c0a5189c33f4efdd649a06b23b6e25a5fa1fdbb2c374af212 AS runtime

WORKDIR /app

RUN addgroup -S petclinic && adduser -S petclinic -G petclinic

COPY --from=build --chown=petclinic:petclinic /workspace/target/*.jar app.jar

USER petclinic

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]