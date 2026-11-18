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
TMP_DIR="$BACKUP_ROOT/.tmp"
REPORT_FILE="$BACKUP_ROOT/last-run.log"
REPORT_TMP="$REPORT_FILE.tmp"

log() {
  echo "[backup] $*"
}

# Rapport structuré lu par minilab-helper-v2 pour le DM de résumé — une ligne
# `service:statut` par cible, statut ∈ ok|skip|missing|fail. Écrit dans un
# fichier temporaire tout au long du run et déplacé (mv atomique) vers
# REPORT_FILE seulement à la fin, pour que le bot (qui poll toutes les 5 min)
# ne puisse jamais lire un rapport à moitié écrit.
report() {
  echo "$1:$2" >>"$REPORT_TMP"
}

# Compare l'artefact temporaire au backup le plus récent du service : identique
# → on jette le temp (rien n'a changé), sinon on l'archive et on ne garde que
# les $keep plus récents ($KEEP par défaut).
commit_backup() {
  local service="$1" tmp_file="$2" ext="$3" keep="${4:-$KEEP}"
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

  ls -1t "$dest_dir"/*."$ext" 2>/dev/null | tail -n +$((keep + 1)) | xargs -r rm --
}

backup_files() {
  local service="$1" src="$2" keep="${3:-$KEEP}"
  if [ ! -d "$src" ]; then
    log "$service : $src introuvable, ignoré"
    report "$service" "missing"
    return
  fi

  local tmp="$TMP_DIR/$service.tar.gz"
  if ! tar czf "$tmp" -C "$(dirname "$src")" "$(basename "$src")" 2>/dev/null; then
    log "$service : échec de l'archivage"
    report "$service" "fail"
    rm -f "$tmp"
    return
  fi

  commit_backup "$service" "$tmp" "tar.gz" "$keep"
}

mkdir -p "$BACKUP_ROOT" "$TMP_DIR"
date +%s >"$REPORT_TMP"

log "── $(date) ──"

# ── Services fichiers ────────────────────────────────────────────────────────
backup_files valheim /mnt/ssd/valheim/worlds_local
backup_files cobblemon /mnt/ssd/cobblemon
backup_files zomboid /mnt/ssd/zomboid
backup_files gitea /mnt/ssd/gitea/data
backup_files pingvin-data /mnt/ssd/pingvin/data
backup_files pingvin-images /mnt/ssd/pingvin/images
backup_files wireguard /mnt/ssd/wireguard/config
backup_files duckdns /mnt/ssd/duckdns/config
backup_files swag /mnt/ssd/swag/config
backup_files nextcloud-config /mnt/ssd/nextcloud/config
backup_files nextcloud-data /mnt/ssd/nextcloud/data 1
backup_files vaultwarden /mnt/ssd/vaultwarden/data
backup_files jellyfin /mnt/ssd/jellyfin/config

# ── Pi-hole : copie directe du dossier de config (plus de dépendance Docker) ─
log "pihole…"
backup_files pihole /mnt/ssd/pihole/etc

# ── MariaDB : dump SQL, jamais de copie à chaud des fichiers vivants ────────
log "mariadb…"
TMP_MARIADB_RAW="$TMP_DIR/mariadb.sql"
TMP_MARIADB="$TMP_DIR/mariadb.sql.gz"

if ! timeout 5 bash -c '>/dev/tcp/mariadb/3306' 2>/dev/null; then
  log "mariadb : conteneur arrêté, ignoré"
  report mariadb "missing"
elif MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb-dump -h mariadb --all-databases -uroot \
  >"$TMP_MARIADB_RAW" 2>/dev/null && [ -s "$TMP_MARIADB_RAW" ]; then
  gzip -c "$TMP_MARIADB_RAW" >"$TMP_MARIADB"
  commit_backup mariadb "$TMP_MARIADB" "sql.gz"
else
  log "mariadb : échec du dump"
  report mariadb "fail"
  rm -f "$TMP_MARIADB"
fi
rm -f "$TMP_MARIADB_RAW"

mv "$REPORT_TMP" "$REPORT_FILE"

log "✅ Terminé — $(date)"
