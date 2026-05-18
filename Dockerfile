# syntax=docker/dockerfile:1

FROM bellsoft/liberica-openjre-alpine-musl:17.0.19-11@sha256:4abefe339e2a7d1c0a5189c33f4efdd649a06b23b6e25a5fa1fdbb2c374af212

WORKDIR /app

RUN addgroup -S petclinic && adduser -S petclinic -G petclinic

COPY --chown=petclinic:petclinic target/app.jar app.jar

USER petclinic

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
