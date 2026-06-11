# Dockerfile Ragnarok Online (rAthena)
# Architecture : ARM64 (Raspberry Pi 4)

FROM debian:bookworm-slim

# Dépendances de compilation rAthena
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    cmake \
    libmariadb-dev \
    zlib1g-dev \
    libpcre3-dev \
    libssl-dev \
    ca-certificates \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/ragnarok

# Clone rAthena (tu peux épingler un tag pour la stabilité)
RUN git clone --depth 1 https://github.com/rathena/rathena.git .

# Compilation
RUN ./configure \
    --enable-buildbot \
    --with-mysql \
    && make -j$(nproc) server

# Script d'entrée
COPY docker-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Ports rAthena
EXPOSE 6900 6121 5121

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
