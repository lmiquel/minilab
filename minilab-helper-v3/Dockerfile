# ── Build stage ────────────────────────────────────────────────────────────────
FROM rust:1-alpine AS builder
WORKDIR /app
RUN apk add --no-cache musl-dev
COPY Cargo.toml Cargo.lock ./
COPY src ./src
# Le build échoue si les tests échouent — pas d'image cassée qui passe.
RUN cargo test --release
RUN cargo build --release

# ── Runtime stage ──────────────────────────────────────────────────────────────
FROM alpine:3
WORKDIR /app
RUN addgroup -S minilab && adduser -S minilab -G minilab
COPY --from=builder /app/target/release/minilab_helper ./minilab_helper
USER minilab
ENTRYPOINT ["./minilab_helper"]
