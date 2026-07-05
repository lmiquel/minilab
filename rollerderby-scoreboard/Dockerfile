FROM eclipse-temurin:17-jdk-alpine AS builder

RUN apk add --no-cache ant git

WORKDIR /build

ARG SCOREBOARD_VERSION=v2027.0
RUN git clone --depth 1 --branch ${SCOREBOARD_VERSION} \
    https://github.com/rollerderby/scoreboard.git .

RUN ant compile

FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

COPY --from=builder /build/lib/crg-scoreboard.jar /app/lib/crg-scoreboard.jar
COPY --from=builder /build/html /app/html
COPY --from=builder /build/config /app/config

EXPOSE 8000

ENTRYPOINT ["java", "-Done-jar.silent=true", "-Dorg.eclipse.jetty.server.LEVEL=WARN", "-jar", "lib/crg-scoreboard.jar"]