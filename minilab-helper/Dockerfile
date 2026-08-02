# ── Build stage ────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json tsconfig.json tsconfig.eslint.json eslint.config.mjs ./
RUN npm ci --include=dev
COPY src ./src
# Le build échoue si le lint ou les tests échouent — pas d'image cassée qui passe.
RUN npm run lint
RUN npm test
RUN npm run build

# ── Runtime stage ──────────────────────────────────────────────────────────────
FROM node:20-alpine
# sudo uniquement pour la commande shutdown
RUN apk add --no-cache sudo
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/dist ./dist
# Autoriser shutdown sans mot de passe (commande précise, pas sudo global)
RUN echo "node ALL=(ALL) NOPASSWD: /sbin/shutdown" >> /etc/sudoers
USER node
CMD ["node", "dist/index.js"]