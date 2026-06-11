#!/bin/bash
# =============================================================================
#  setup-rpi.sh — Configuration initiale du Raspberry Pi 4
#  Raspberry Pi OS Lite 64-bit (Bookworm, basé sur Debian 12)
#  À exécuter en root une seule fois après l'installation
# =============================================================================
set -e

MINILAB_USER="minilab"
PROJECT_DIR="/home/$MINILAB_USER/minilab"

echo "╔══════════════════════════════════════════════════╗"
echo "║         Setup minilab — démarrage                ║"
echo "╚══════════════════════════════════════════════════╝"

echo ""
echo "=== 1. Mise à jour du système ==="
apt-get update && apt-get upgrade -y

echo ""
echo "=== 2. Installation des paquets essentiels ==="
# Note : linux-modules-extra-raspi est inutile — les modules WireGuard
# sont déjà inclus dans le noyau officiel Raspberry Pi OS
apt-get install -y \
    curl \
    git \
    tree \
    htop \
    ufw \
    fail2ban \
    unattended-upgrades \
    ca-certificates \
    gnupg

echo ""
echo "=== 3. Installation de Docker ==="
if ! command -v docker &>/dev/null; then
  # Le script officiel détecte automatiquement Debian/ARM64 (RPi OS Bookworm)
  # et installe les bons paquets — pas besoin de repo Ubuntu
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  echo "Docker installé."
else
  echo "Docker déjà présent, on passe."
fi

echo ""
echo "=== 4. Configuration de l'utilisateur $MINILAB_USER ==="
# Sur Raspberry Pi OS, l'utilisateur est déjà créé par l'Imager.
# On se contente de lui donner les droits Docker et sudo shutdown.
if id "$MINILAB_USER" &>/dev/null; then
  echo "Utilisateur $MINILAB_USER trouvé (créé par l'Imager)."
else
  # Fallback : création manuelle si l'utilisateur n'existe pas
  adduser --disabled-password --gecos "" "$MINILAB_USER"
  echo "Utilisateur $MINILAB_USER créé."
fi
usermod -aG docker "$MINILAB_USER"

# Droit sudo limité : uniquement shutdown (pas de sudo global)
if [ ! -f /etc/sudoers.d/minilab-shutdown ]; then
  echo "$MINILAB_USER ALL=(ALL) NOPASSWD: /sbin/shutdown" \
    > /etc/sudoers.d/minilab-shutdown
  chmod 0440 /etc/sudoers.d/minilab-shutdown
  echo "Droit shutdown accordé à $MINILAB_USER."
fi

echo ""
echo "=== 5. Configuration du pare-feu UFW ==="
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH
ufw allow ssh

# WireGuard VPN (seul port exposé sur Internet avec SSH)
ufw allow 51820/udp

# Pi-hole — interface web admin (réseau local + VPN uniquement, pas Internet)
ufw allow from 192.168.0.0/16 to any port 8080 proto tcp  # LAN classe B
ufw allow from 10.0.0.0/8    to any port 8080 proto tcp  # VPN / LAN classe A
ufw allow from 172.16.0.0/12 to any port 8080 proto tcp  # Docker networks

# Pi-hole — DNS port 53 (réseau local + Docker uniquement)
ufw allow from 192.168.0.0/16 to any port 53
ufw allow from 10.0.0.0/8    to any port 53
ufw allow from 172.16.0.0/12 to any port 53

# Les ports de jeu (RO 6900/6121/5121, Valheim 2456-2458) ne sont PAS
# exposés sur Internet — les joueurs passent obligatoirement par WireGuard
ufw --force enable
echo "UFW configuré."

echo ""
echo "=== 6. Activation de fail2ban ==="
systemctl enable --now fail2ban

echo ""
echo "=== 7. Mises à jour de sécurité automatiques ==="
dpkg-reconfigure --priority=low unattended-upgrades

echo ""
echo "=== 8. Optimisations + activation du forwarding IP ==="
# Forwarding IP requis par WireGuard ET Pi-hole (relay DNS vers Cloudflare)
# Évite d'écrire en double si le script est relancé
if ! grep -q "minilab optimizations" /etc/sysctl.conf; then
  cat >> /etc/sysctl.conf <<'SYSCTL'

# ── minilab optimizations ──
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.swappiness = 10
# Forwarding IP (WireGuard + Pi-hole DNS relay)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
SYSCTL
fi
sysctl -p

# Note : sur Raspberry Pi OS, systemd-resolved n'est PAS présent.
# Le port 53 est donc libre pour Pi-hole dès le départ, sans rien à faire.

echo ""
echo "=== 9. Boot depuis le SSD (optionnel mais recommandé) ==="
echo "  Pour booter l'OS depuis le SSD plutôt que la carte SD :"
echo "  sudo raspi-config → Advanced Options → Boot Order → USB Boot"
echo "  (nécessite un reboot + re-flash du SSD avec RPi OS Lite)"
echo "  Pour ce projet, la carte SD pour l'OS + SSD pour les données est suffisant."

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  ✅  Setup système terminé !                     ║"
echo "║  Prochaine étape : ./scripts/setup-ssd.sh        ║"
echo "╚══════════════════════════════════════════════════╝"
