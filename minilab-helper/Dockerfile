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

USER node

CMD ["node", "dist/index.js"]
