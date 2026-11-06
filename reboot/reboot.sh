#!/bin/bash
# =============================================================================
#  reboot.sh — Reboot mensuel du Pi, le 1er à 4h (voir Dockerfile), une fois la
#  backup du jour terminée. Au boot, minilab.service met tous les services à
#  jour (scripts/boot-update.sh).
#  `reboot.sh --check` vérifie seulement que le reboot est autorisé.
# =============================================================================

REPORT_FILE="/mnt/ssd/backups/last-run.log"
PENDING_FILE="/mnt/ssd/reboot/pending"
MAX_WAIT_MIN=180

log() {
  echo "[reboot] $*"
}

login1() {
  dbus-send --system --print-reply --dest=org.freedesktop.login1 \
    /org/freedesktop/login1 "org.freedesktop.login1.Manager.$1" "${@:2}"
}

if [ "$1" = "--check" ]; then
  login1 CanReboot
  exit
fi

date +%s >"$PENDING_FILE"

today=$(date -d 00:00 +%s)
for ((i = 0; i < MAX_WAIT_MIN; i++)); do
  last=$(head -n 1 "$REPORT_FILE" 2>/dev/null)
  [[ "$last" =~ ^[0-9]+$ ]] && [ "$last" -ge "$today" ] && break
  sleep 60
done

if [ "$i" -lt "$MAX_WAIT_MIN" ]; then
  log "backup du jour terminée, reboot"
else
  log "pas de backup du jour après ${MAX_WAIT_MIN} min, reboot quand même"
fi

if ! login1 Reboot boolean:false; then
  log "échec de la demande de reboot"
  rm -f "$PENDING_FILE"
fi
