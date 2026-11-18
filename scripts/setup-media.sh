#!/bin/bash
# =============================================================================
#  setup-media.sh — Volume des médias (« Médias » dans Nextcloud, bibliothèque
#  Jellyfin) plafonné à MEDIA_SIZE : une image ext4 sur le SSD, montée en loop.
#  À exécuter en root sur le Raspberry Pi, une fois le SSD monté (idempotent).
# =============================================================================
set -euo pipefail

MEDIA_SIZE="40G"
IMAGE="/mnt/ssd/media.img"
MOUNT_POINT="/mnt/ssd/media"
FSTAB_LINE="$IMAGE  $MOUNT_POINT  ext4  loop,discard,noatime,nofail,x-systemd.requires-mounts-for=/mnt/ssd  0  0"

created=false
if [ ! -f "$IMAGE" ]; then
  truncate -s "$MEDIA_SIZE" "$IMAGE"
  mkfs.ext4 -q -F -m 0 -L minilab-media "$IMAGE"
  created=true
  echo "Image $IMAGE créée ($MEDIA_SIZE)."
fi

mkdir -p "$MOUNT_POINT"
if ! mountpoint -q "$MOUNT_POINT"; then
  [ -z "$(ls -A "$MOUNT_POINT")" ] || { echo "ERREUR : $MOUNT_POINT n'est pas vide."; exit 1; }
  chattr +i "$MOUNT_POINT"
fi

if ! grep -qF "$IMAGE" /etc/fstab; then
  printf '\n# minilab médias (%s)\n%s\n' "$MEDIA_SIZE" "$FSTAB_LINE" >>/etc/fstab
  echo "Entrée fstab ajoutée."
fi

systemctl daemon-reload
mountpoint -q "$MOUNT_POINT" || mount "$MOUNT_POINT"
if $created; then
  rmdir "$MOUNT_POINT/lost+found" 2>/dev/null || true
fi
chown 1000:1000 "$MOUNT_POINT"

df -h "$MOUNT_POINT"
