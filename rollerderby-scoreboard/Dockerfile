FROM eclipse-temurin:17-jdk AS builder

RUN apt-get update && apt-get install -y --no-install-recommends ant git curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ADD https://github.com/rollerderby/scoreboard/releases.atom /tmp/releases.atom

ARG SCOREBOARD_VERSION=latest
RUN if [ "$SCOREBOARD_VERSION" = latest ]; then \
      url=$(curl -fsSLo /dev/null -w '%{url_effective}' https://github.com/rollerderby/scoreboard/releases/latest) \
      && SCOREBOARD_VERSION=${url##*/}; \
    fi \
    && echo "Scoreboard : $SCOREBOARD_VERSION" \
    && git clone --depth 1 --branch "$SCOREBOARD_VERSION" \
    https://github.com/rollerderby/scoreboard.git .

RUN ant compile

FROM eclipse-temurin:17-jre

WORKDIR /app

COPY --from=builder /build/lib/crg-scoreboard.jar /app/lib/crg-scoreboard.jar
COPY --from=builder /build/html /app/html
COPY --from=builder /build/config /app/config

EXPOSE 8000

ENTRYPOINT ["java", "-Done-jar.silent=true", "-Dorg.eclipse.jetty.server.LEVEL=WARN", "-jar", "lib/crg-scoreboard.jar"]