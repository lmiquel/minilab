# ── Build stage ────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json tsconfig.json ./
RUN npm ci --include=dev
COPY src ./src
RUN npm run build

# ── Runtime stage ──────────────────────────────────────────────────────────────
FROM node:20-alpine

# Outils nécessaires pour WireGuard + shutdown
RUN apk add --no-cache wireguard-tools sudo

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist

# Autoriser shutdown sans mot de passe (commande précise, pas sudo global)
RUN echo "node ALL=(ALL) NOPASSWD: /sbin/shutdown" >> /etc/sudoers

# Accès au socket Docker :
# Le socket /var/run/docker.sock appartient au groupe "docker" de l'hôte.
# On récupère son GID au moment du build via un ARG, puis on crée le groupe
# correspondant dans le conteneur et on y ajoute l'utilisateur "node".
# La valeur par défaut 998 est le GID standard sur RPi OS — vérifiable avec :
#   stat -c '%g' /var/run/docker.sock  (sur le Pi)
ARG DOCKER_GID=998
RUN addgroup -g ${DOCKER_GID} docker_host 2>/dev/null || true \
    && addgroup node docker_host

USER node

CMD ["node", "dist/index.js"]