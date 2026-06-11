#!/bin/bash
# =============================================================================
#  setup-ssd.sh — Monte le SSD NVMe USB et prépare les répertoires
#  À exécuter une seule fois en root sur le Raspberry Pi
# =============================================================================
set -e

DEVICE="/dev/sda"        # Vérifie avec `lsblk` que c'est bien ton SSD
PARTITION="${DEVICE}1"
MOUNT_POINT="/mnt/ssd"
FSTAB_ENTRY_COMMENT="# minilab SSD NVMe"

echo "=== 1. Détection du disque ==="
lsblk "$DEVICE" || { echo "ERREUR : $DEVICE non trouvé. Vérifie avec lsblk."; exit 1; }

echo ""
echo "=== 2. Partitionnement (GPT, une seule partition ext4) ==="
echo "⚠️  ATTENTION : ceci EFFACE toutes les données sur $DEVICE"
read -rp "Continuer ? (oui/non) : " confirm
[[ "$confirm" == "oui" ]] || { echo "Annulé."; exit 0; }

parted "$DEVICE" --script mklabel gpt
parted "$DEVICE" --script mkpart primary ext4 0% 100%
mkfs.ext4 -L minilab-ssd "$PARTITION"

echo ""
echo "=== 3. Montage permanent ==="
mkdir -p "$MOUNT_POINT"

# Récupère l'UUID du disque
UUID=$(blkid -s UUID -o value "$PARTITION")
echo "UUID détecté : $UUID"

# Ajoute au fstab si pas déjà présent
if ! grep -q "$UUID" /etc/fstab; then
  echo "" >> /etc/fstab
  echo "$FSTAB_ENTRY_COMMENT" >> /etc/fstab
  echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults,noatime  0  2" >> /etc/fstab
  echo "Entrée fstab ajoutée."
else
  echo "Déjà dans fstab, on passe."
fi

mount -a

echo ""
echo "=== 4. Création de l'arborescence ==="
mkdir -p \
  "$MOUNT_POINT/ragnarok/mysql" \
  "$MOUNT_POINT/ragnarok/data" \
  "$MOUNT_POINT/valheim" \
  "$MOUNT_POINT/valheim/backups" \
  "$MOUNT_POINT/pihole/etc" \
  "$MOUNT_POINT/pihole/dnsmasq" \
  "$MOUNT_POINT/wireguard/config"

# Droits pour Docker (uid 1000 = utilisateur standard)
chown -R 1000:1000 "$MOUNT_POINT"

echo ""
echo "=== ✅ SSD prêt ! Arborescence : ==="
tree "$MOUNT_POINT" 2>/dev/null || ls -la "$MOUNT_POINT"
