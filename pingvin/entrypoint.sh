#!/bin/sh
# =============================================================================
#  entrypoint.sh — Démarrage de Pingvin : attend l'URL du tunnel cloudflared,
#  l'écrit comme App URL dans $CONFIG_FILE, puis lance le démarrage d'origine.
#  Sans URL au bout de TIMEOUT secondes, Pingvin démarre quand même.
# =============================================================================

TUNNEL_URL="http://cloudflared:20241/quicktunnel"
TIMEOUT=120

i=0
hostname=""
while [ -z "$hostname" ] && [ "$i" -lt "$TIMEOUT" ]; do
  hostname=$(wget -qO- -T 5 "$TUNNEL_URL" 2>/dev/null |
    sed -n 's/.*"hostname": *"\([^"]*\)".*/\1/p')
  [ -n "$hostname" ] || sleep 1
  i=$((i + 1))
done

if [ -n "$hostname" ]; then
  printf 'general:\n  appUrl: https://%s\n' "$hostname" >"$CONFIG_FILE"
  echo "[minilab] App URL → https://$hostname"
else
  echo "[minilab] pas d'URL de tunnel après ${TIMEOUT}s"
fi

cd /opt/app && exec sh ./scripts/docker/entrypoint.sh
