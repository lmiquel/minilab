# Dockerfile Ragnarok Online (rAthena)
# Architecture : ARM64 (Raspberry Pi 4)

FROM debian:bookworm-slim

# Dépendances de compilation rAthena
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    cmake \
    libmariadb-dev \
    libmariadb-dev-compat \
    zlib1g-dev \
    libpcre2-dev \
    libssl-dev \
    ca-certificates \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/ragnarok

# Clone rAthena
RUN git clone --depth 1 https://github.com/rathena/rathena.git .

# Compilation via CMake (build dans un sous-répertoire séparé, obligatoire)
RUN mkdir build && cd build && \
    cmake .. \
        -DINSTALL_TO_SOURCE=ON \
        -DENABLE_EXTRA_BUILDBOT_CODE=OFF \
        -DPACKETVER=20211103 \
    && make -j$(nproc) && \
    make install

# Script d'entrée
COPY docker-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Ports rAthena
EXPOSE 6900 6121 5121

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]