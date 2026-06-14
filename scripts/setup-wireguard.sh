#!/bin/bash
# =============================================================================
#  setup-wireguard.sh — Installation et configuration de WireGuard natif
#  (hors Docker, directement sur l'hôte RPi OS Bookworm)
#  À exécuter en root une seule fois
# =============================================================================
set -e

# ── Variables à renseigner ────────────────────────────────────────────────────
SERVER_URL=$(grep WG_SERVER_URL ~/minilab/.env)
if [ -z "$SERVER_URL" ]; then
  echo "Erreur : WG_SERVER_URL non trouvé dans ~/minilab/.env"
  exit 1
fi
SERVER_PORT="51820"
INTERNAL_SUBNET="10.13.13"
SERVER_IP="${INTERNAL_SUBNET}.1"
CONFIG_DIR="/etc/wireguard"
PEERS_DIR="/mnt/ssd/wireguard/peers"

# Récupère les peers depuis le .env du projet
PEERS_RAW=$(grep WG_PEERS ~/minilab/.env 2>/dev/null | cut -d= -f2)
if [ -z "$PEERS_RAW" ]; then
  echo "Erreur : WG_PEERS non trouvé dans ~/minilab/.env"
  echo "Exemple : WG_PEERS=alice,bob,charlie"
  exit 1
fi

echo "╔══════════════════════════════════════════════════╗"
echo "║     Setup WireGuard natif — minilab              ║"
echo "╚══════════════════════════════════════════════════╝"

echo ""
echo "=== 1. Installation de WireGuard ==="
apt-get update
apt-get install -y wireguard wireguard-tools qrencode

echo ""
echo "=== 2. Génération des clés serveur ==="
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/server_private.key" ]; then
  wg genkey | tee "$CONFIG_DIR/server_private.key" | wg pubkey > "$CONFIG_DIR/server_public.key"
  chmod 600 "$CONFIG_DIR/server_private.key"
  echo "Clés serveur générées."
else
  echo "Clés serveur déjà présentes, on conserve."
fi

SERVER_PRIVATE=$(cat "$CONFIG_DIR/server_private.key")
SERVER_PUBLIC=$(cat "$CONFIG_DIR/server_public.key")

echo ""
echo "=== 3. Génération des clés et configs peers ==="
mkdir -p "$PEERS_DIR"

PEERS_CONFIG=""
PEER_IP_COUNTER=2

IFS=',' read -ra PEERS <<< "$PEERS_RAW"
for PEER in "${PEERS[@]}"; do
  PEER=$(echo "$PEER" | tr -d ' ')
  PEER_DIR="$PEERS_DIR/$PEER"
  mkdir -p "$PEER_DIR"

  if [ ! -f "$PEER_DIR/private.key" ]; then
    wg genkey | tee "$PEER_DIR/private.key" | wg pubkey > "$PEER_DIR/public.key"
    wg genpsk > "$PEER_DIR/preshared.key"
    chmod 600 "$PEER_DIR/private.key" "$PEER_DIR/preshared.key"
  fi

  PEER_PRIVATE=$(cat "$PEER_DIR/private.key")
  PEER_PUBLIC=$(cat "$PEER_DIR/public.key")
  PEER_PSK=$(cat "$PEER_DIR/preshared.key")
  PEER_IP="${INTERNAL_SUBNET}.${PEER_IP_COUNTER}"

  # Config client (.conf à envoyer au peer)
  cat > "$PEER_DIR/${PEER}.conf" << PEERCONF
[Interface]
PrivateKey = ${PEER_PRIVATE}
Address = ${PEER_IP}/32
DNS = 192.168.1.97

[Peer]
PublicKey = ${SERVER_PUBLIC}
PresharedKey = ${PEER_PSK}
AllowedIPs = ${INTERNAL_SUBNET}.0/24, 172.20.0.0/24
Endpoint = ${SERVER_URL}:${SERVER_PORT}
PersistentKeepalive = 25
PEERCONF

  # Génère le QR code
  qrencode -t png -o "$PEER_DIR/${PEER}.png" < "$PEER_DIR/${PEER}.conf"
  echo "  → Peer $PEER : $PEER_IP — config dans $PEER_DIR/${PEER}.conf"

  # Bloc [Peer] pour la config serveur
  PEERS_CONFIG="${PEERS_CONFIG}
[Peer]
# ${PEER}
PublicKey = ${PEER_PUBLIC}
PresharedKey = ${PEER_PSK}
AllowedIPs = ${PEER_IP}/32
"
  PEER_IP_COUNTER=$((PEER_IP_COUNTER + 1))
done

echo ""
echo "=== 4. Génération de la config serveur (wg0.conf) ==="

# Détecte l'interface réseau active (eth0 ou wlan0)
NET_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo "Interface réseau détectée : $NET_IFACE"

cat > "$CONFIG_DIR/wg0.conf" << SERVERCONF
[Interface]
Address = ${SERVER_IP}/24
ListenPort = ${SERVER_PORT}
PrivateKey = ${SERVER_PRIVATE}

# NAT : permet aux peers d'accéder à Internet et au réseau Docker via le tunnel
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${NET_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${NET_IFACE} -j MASQUERADE
${PEERS_CONFIG}
SERVERCONF

chmod 600 "$CONFIG_DIR/wg0.conf"

echo ""
echo "=== 5. Activation et démarrage de WireGuard ==="
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

echo ""
echo "=== 6. Vérification ==="
wg show

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  WireGuard natif opérationnel !                         ║"
echo "║  Configs peers dans : $PEERS_DIR"
echo "║  Afficher QR code   : qrencode -t ansiutf8 < /mnt/ssd/wireguard/peers/NOM/NOM.conf"
echo "╚══════════════════════════════════════════════════════════════╝"
