#!/bin/bash
# =============================================================================
#  backup.sh — Sauvegarde quotidienne des données minilab.
#  Tourne dans son propre conteneur, planifié à 4h du matin (voir Dockerfile).
#  Pas de `set -e` : best-effort, un service en panne ne doit pas empêcher la
#  sauvegarde des autres.
# =============================================================================

BACKUP_ROOT="/mnt/ssd/backups"
DATE=$(date +%Y-%m-%d_%H-%M)
KEEP=5
REPORT_FILE="$BACKUP_ROOT/last-run.log"

log() {
  echo "[backup] $*"
}

# Rapport structuré lu par minilab-helper-v2 pour le DM de résumé — une ligne
# `service:statut` par cible, statut ∈ ok|skip|missing|fail.
report() {
  echo "$1:$2" >>"$REPORT_FILE"
}

# Compare l'artefact temporaire au backup le plus récent du service : identique
# → on jette le temp (rien n'a changé), sinon on l'archive et on ne garde que
# les $KEEP plus récents.
commit_backup() {
  local service="$1" tmp_file="$2" ext="$3"
  local dest_dir="$BACKUP_ROOT/$service"
  mkdir -p "$dest_dir"

  local latest
  latest=$(ls -1t "$dest_dir"/*."$ext" 2>/dev/null | head -n 1)

  if [ -n "$latest" ] && [ "$(sha256sum "$tmp_file" | cut -d' ' -f1)" = "$(sha256sum "$latest" | cut -d' ' -f1)" ]; then
    log "$service : pas de changement, backup ignorée"
    report "$service" "skip"
    rm -f "$tmp_file"
    return
  fi

  mv "$tmp_file" "$dest_dir/$DATE.$ext"
  log "$service : nouvelle backup -> $dest_dir/$DATE.$ext"
  report "$service" "ok"

  ls -1t "$dest_dir"/*."$ext" 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm --
}

backup_files() {
  local service="$1" src="$2"
  if [ ! -d "$src" ]; then
    log "$service : $src introuvable, ignoré"
    report "$service" "missing"
    return
  fi

  local tmp="/tmp/$service.tar.gz"
  if ! tar czf "$tmp" -C "$(dirname "$src")" "$(basename "$src")" 2>/dev/null; then
    log "$service : échec de l'archivage"
    report "$service" "fail"
    rm -f "$tmp"
    return
  fi

  commit_backup "$service" "$tmp" "tar.gz"
}

mkdir -p "$BACKUP_ROOT"
date -Iseconds >"$REPORT_FILE"

log "── $(date) ──"

# ── Services fichiers ────────────────────────────────────────────────────────
backup_files valheim /mnt/ssd/valheim/worlds
backup_files cobblemon /mnt/ssd/cobblemon
backup_files terraria /mnt/ssd/terraria/worlds
backup_files gitea /mnt/ssd/gitea/data
backup_files pingvin-data /mnt/ssd/pingvin/data
backup_files pingvin-images /mnt/ssd/pingvin/images
backup_files wireguard /mnt/ssd/wireguard/config
backup_files duckdns /mnt/ssd/duckdns/config

# ── Pi-hole : teleporter en priorité, fallback copie du dossier ─────────────
log "pihole…"
TMP_PIHOLE="/tmp/pihole.tar.gz"
if docker exec pihole pihole -a -t /tmp/pihole-teleporter.tar.gz >/dev/null 2>&1 \
  && docker cp pihole:/tmp/pihole-teleporter.tar.gz "$TMP_PIHOLE" >/dev/null 2>&1; then
  docker exec pihole rm -f /tmp/pihole-teleporter.tar.gz >/dev/null 2>&1 || true
  commit_backup pihole "$TMP_PIHOLE" "tar.gz"
else
  backup_files pihole /mnt/ssd/pihole/etc
fi

# ── MariaDB : dump SQL, jamais de copie à chaud des fichiers vivants ────────
log "mariadb…"
TMP_MARIADB_RAW="/tmp/mariadb.sql"
TMP_MARIADB="/tmp/mariadb.sql.gz"
if docker exec mariadb mariadb-dump --all-databases -uroot -p"$MARIADB_ROOT_PASSWORD" \
  >"$TMP_MARIADB_RAW" 2>/dev/null && [ -s "$TMP_MARIADB_RAW" ]; then
  gzip -c "$TMP_MARIADB_RAW" >"$TMP_MARIADB"
  commit_backup mariadb "$TMP_MARIADB" "sql.gz"
else
  log "mariadb : échec du dump (conteneur arrêté ?)"
  report mariadb "fail"
  rm -f "$TMP_MARIADB"
fi
rm -f "$TMP_MARIADB_RAW"

log "✅ Terminé — $(date)"
