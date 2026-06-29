#!/bin/bash
# =============================================================================
#  backup.sh — Sauvegarde quotidienne des données minilab vers /mnt/ssd/backups
#  À planifier via cron : 0 3 * * * /home/minilab/minilab/scripts/backup.sh
# =============================================================================

BACKUP_ROOT="/mnt/ssd/backups"
DATE=$(date +%Y-%m-%d_%H-%M)
RETENTION_DAYS=7

mkdir -p "$BACKUP_ROOT"

echo "[backup] ── $(date) ──"

# ── Valheim : copie des fichiers monde ────────────────────────────────────────
echo "[backup] Valheim…"
DEST_VALHEIM="$BACKUP_ROOT/valheim/$DATE"
mkdir -p "$DEST_VALHEIM"
cp -a /mnt/ssd/valheim/worlds "$DEST_VALHEIM/" 2>/dev/null || true
echo "[backup] Valheim OK → $DEST_VALHEIM"

# ── Pi-hole : sauvegarde de la configuration et des listes ───────────────────
echo "[backup] Pi-hole…"
DEST_PIHOLE="$BACKUP_ROOT/pihole/$DATE"
mkdir -p "$DEST_PIHOLE"
# teleporter = export natif Pi-hole (gravity.db + config + custom lists)
docker exec pihole pihole -a -t "$DEST_PIHOLE/pihole-teleporter.tar.gz" 2>/dev/null \
  || cp -a /mnt/ssd/pihole/etc "$DEST_PIHOLE/etc" 2>/dev/null || true
echo "[backup] Pi-hole OK → $DEST_PIHOLE"

# ── Nettoyage des vieilles sauvegardes ────────────────────────────────────────
echo "[backup] Nettoyage des backups > $RETENTION_DAYS jours…"
find "$BACKUP_ROOT" -mindepth 2 -maxdepth 2 -type d -mtime +$RETENTION_DAYS \
  -exec rm -rf {} + 2>/dev/null || true

echo "[backup] ✅ Terminé — $(date)"
