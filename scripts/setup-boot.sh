#!/bin/bash
# =============================================================================
#  setup-boot.sh — Lance la stack minilab via docker compose au boot
#  À exécuter en root sur le Raspberry Pi, une fois le .env rempli (idempotent)
#
#  Sans ça, au boot, c'est dockerd qui relance les conteneurs (restart:
#  unless-stopped) dans le désordre, sans depends_on ni healthchecks : un
#  service en network_mode service:wireguard peut démarrer avant wireguard et
#  rester planté.
#
#  Le principe : à l'extinction, ExecStop fait un `docker compose stop` → les
#  conteneurs sont « arrêtés manuellement », donc dockerd ne les relance pas au
#  boot. Ensuite, ExecStart fait `docker compose up -d`, qui démarre seulement
#  les services par défaut, dans l'ordre. La politique unless-stopped continue
#  de relancer un conteneur qui crashe en cours de route.
#
#  Limite : après une coupure de courant, ExecStop n'a pas tourné, donc dockerd
#  relance tout ce qui tournait, dans le désordre. Le `up -d` qui suit
#  redémarre ce qui a échoué.
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UNIT_FILE="/etc/systemd/system/minilab.service"
DOCKER_BIN="$(command -v docker)"

[ -f "$REPO_DIR/.env" ] || { echo "ERREUR : $REPO_DIR/.env introuvable."; exit 1; }
(cd "$REPO_DIR" && "$DOCKER_BIN" compose config -q) || { echo "ERREUR : config compose invalide."; exit 1; }

echo "=== Écriture de $UNIT_FILE (repo : $REPO_DIR) ==="
cat >"$UNIT_FILE" <<EOF
[Unit]
Description=minilab (docker compose)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target
RequiresMountsFor=/mnt/ssd

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$REPO_DIR
ExecStart=$DOCKER_BIN compose up -d
ExecStartPost=-/bin/bash $REPO_DIR/scripts/boot-update.sh
ExecStop=$DOCKER_BIN compose --profile "*" stop --timeout 120
Restart=on-failure
RestartSec=30
TimeoutStartSec=30min
TimeoutStopSec=10min

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now minilab.service
echo "=== ✅ minilab.service activé ==="
systemctl --no-pager status minilab.service | head -n 5
