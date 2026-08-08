FROM debian:bookworm-slim AS fetch

RUN apt-get update && apt-get install -y --no-install-recommends curl unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /fetch

# Build officiel pré-compilé, publié sur les GitHub Releases de magefree/mage.
# Bump ces deux ARGs pour changer de version (pas de build Maven local sur le Pi).
ARG XMAGE_RELEASE_TAG=xmage_1.4.60V3
ARG XMAGE_RELEASE_ASSET=mage-full_1.4.60-dev_2026-07-11_16-06.zip

RUN curl -sL -o mage-full.zip \
      "https://github.com/magefree/mage/releases/download/${XMAGE_RELEASE_TAG}/${XMAGE_RELEASE_ASSET}" \
    && unzip -q mage-full.zip "xmage/mage-server/*" \
    && rm mage-full.zip

FROM eclipse-temurin:21-jre

WORKDIR /app

COPY --from=fetch /fetch/xmage/mage-server/ /app/
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 17171 17179

ENTRYPOINT ["/app/docker-entrypoint.sh"]
