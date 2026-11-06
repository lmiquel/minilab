#!/bin/bash
# =============================================================================
#  boot-update.sh — Lancé par minilab.service une fois les services par défaut
#  démarrés : pull des images, rebuild des images maison, seuls les services par
#  défaut restent running, les autres sont recréés à jour mais arrêtés, puis
#  nettoyage.
# =============================================================================
set -o pipefail
trap 'rm -f /mnt/ssd/reboot/pending' EXIT
cd "$(dirname "$0")/.." || exit 1

all=$(docker compose --profile "*" config --services | LC_ALL=C sort) || exit 1
default=$(docker compose config --services | LC_ALL=C sort) || exit 1
[ -n "$default" ] || exit 1
mapfile -t optional < <(LC_ALL=C comm -23 <(echo "$all") <(echo "$default"))

docker compose --profile "*" pull --ignore-buildable --ignore-pull-failures
docker compose --profile "*" build --pull

if [ "${#optional[@]}" -gt 0 ]; then
  docker compose --profile "*" stop --timeout 120 "${optional[@]}"
fi

docker compose up -d

if [ "${#optional[@]}" -gt 0 ]; then
  docker compose --profile "*" create "${optional[@]}"
fi

docker image prune -f
