#!/bin/bash
set -e

DB_HOST="${DB_HOST:-ragnarok-db}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-ragnarok}"
DB_PASSWORD="${DB_PASSWORD:-changeme}"
DB_NAME="${DB_NAME:-ragnarok}"

echo "[rAthena] Attente de MariaDB sur $DB_HOST:$DB_PORT…"
until nc -z "$DB_HOST" "$DB_PORT"; do
  sleep 2
done
echo "[rAthena] Base de données disponible."

# ── Génération des fichiers de conf à partir des variables d'environnement ──
patch_conf() {
  local file="$1" key="$2" value="$3"
  if [ -f "$file" ]; then
    sed -i "s|^$key:.*|$key: $value|" "$file"
  fi
}

# inter_athena.conf
INTER_CONF="conf/inter_athena.conf"
patch_conf "$INTER_CONF" "login_server_ip"  "$DB_HOST"
patch_conf "$INTER_CONF" "login_server_id"  "$DB_USER"
patch_conf "$INTER_CONF" "login_server_pw"  "$DB_PASSWORD"
patch_conf "$INTER_CONF" "login_server_db"  "$DB_NAME"
patch_conf "$INTER_CONF" "ipban_db_ip"      "$DB_HOST"
patch_conf "$INTER_CONF" "ipban_db_id"      "$DB_USER"
patch_conf "$INTER_CONF" "ipban_db_pw"      "$DB_PASSWORD"
patch_conf "$INTER_CONF" "ipban_db_db"      "$DB_NAME"
patch_conf "$INTER_CONF" "char_server_ip"   "$DB_HOST"
patch_conf "$INTER_CONF" "char_server_id"   "$DB_USER"
patch_conf "$INTER_CONF" "char_server_pw"   "$DB_PASSWORD"
patch_conf "$INTER_CONF" "char_server_db"   "$DB_NAME"
patch_conf "$INTER_CONF" "map_server_ip"    "$DB_HOST"
patch_conf "$INTER_CONF" "map_server_id"    "$DB_USER"
patch_conf "$INTER_CONF" "map_server_pw"    "$DB_PASSWORD"
patch_conf "$INTER_CONF" "map_server_db"    "$DB_NAME"
patch_conf "$INTER_CONF" "log_db_ip"        "$DB_HOST"
patch_conf "$INTER_CONF" "log_db_id"        "$DB_USER"
patch_conf "$INTER_CONF" "log_db_pw"        "$DB_PASSWORD"

# char_athena.conf
CHAR_CONF="conf/char_athena.conf"
patch_conf "$CHAR_CONF" "server_name" "${SERVER_NAME:-MyRO}"

echo "[rAthena] Lancement des serveurs…"
./login-server &
sleep 2
./char-server &
sleep 2
./map-server &

# Attente indéfinie (gestion des signaux)
wait
