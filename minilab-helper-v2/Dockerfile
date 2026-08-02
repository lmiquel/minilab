# ── Build stage ────────────────────────────────────────────────────────────────
FROM ghcr.io/gleam-lang/gleam:v1.18.1-erlang-alpine AS builder
WORKDIR /app
COPY gleam.toml manifest.toml ./
RUN gleam deps download
COPY src ./src
COPY test ./test
# Le build échoue si les tests échouent — pas d'image cassée qui passe.
RUN gleam test
RUN gleam export erlang-shipment

# ── Runtime stage ──────────────────────────────────────────────────────────────
FROM erlang:29-alpine
WORKDIR /app
RUN addgroup -S minilab && adduser -S minilab -G minilab
COPY --from=builder /app/build/erlang-shipment ./
USER minilab
ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]
CMD ["run"]
