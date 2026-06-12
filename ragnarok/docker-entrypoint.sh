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

# ── Configuration via le système import/ de rAthena ──────────────────────────
# Les fichiers dans conf/import/ surchargent la config par défaut sans la modifier.
# C'est la méthode officielle recommandée par rAthena.

mkdir -p conf/import

# inter_athena.conf — connexion à la base de données
cat > conf/import/inter_conf.txt << CONF
// Connexion MariaDB — généré par docker-entrypoint.sh
login_server_ip: ${DB_HOST}
login_server_id: ${DB_USER}
login_server_pw: ${DB_PASSWORD}
login_server_db: ${DB_NAME}
ipban_db_ip: ${DB_HOST}
ipban_db_id: ${DB_USER}
ipban_db_pw: ${DB_PASSWORD}
ipban_db_db: ${DB_NAME}
char_server_ip: ${DB_HOST}
char_server_id: ${DB_USER}
char_server_pw: ${DB_PASSWORD}
char_server_db: ${DB_NAME}
map_server_ip: ${DB_HOST}
map_server_id: ${DB_USER}
map_server_pw: ${DB_PASSWORD}
map_server_db: ${DB_NAME}
log_db_ip: ${DB_HOST}
log_db_id: ${DB_USER}
log_db_pw: ${DB_PASSWORD}
log_db_db: ${DB_NAME}
CONF

# char_athena.conf — nom du serveur
cat > conf/import/char_conf.txt << CONF
// Config char-server — généré par docker-entrypoint.sh
server_name: ${SERVER_NAME:-minilab-ro}
CONF

echo "[rAthena] Configuration appliquée via conf/import/"
echo "[rAthena] Lancement des serveurs…"

./login-server &
sleep 2
./char-server &
sleep 2
./map-server &

# Attente indéfinie — gestion propre des signaux (SIGTERM → arrêt gracieux)
wait