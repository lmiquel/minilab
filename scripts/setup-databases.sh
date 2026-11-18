#!/bin/bash
# =============================================================================
#  setup-databases.sh — Crée les bases et utilisateurs MariaDB des services.
#  Idempotent : à lancer sur le Pi, conteneur mariadb démarré.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

env_value() {
  local value
  value=$(grep -E "^$1=" .env | tail -n 1 | cut -d= -f2-)
  value="${value%\"}" && value="${value#\"}"
  value="${value%\'}" && value="${value#\'}"
  [ -n "$value" ] || { echo "ERREUR : $1 vide ou absent de .env" >&2; exit 1; }
  printf '%s' "$value"
}

sql=""
for db in gitea nextcloud vaultwarden; do
  password=$(env_value "${db^^}_DB_PASSWORD")
  sql+="CREATE DATABASE IF NOT EXISTS \`$db\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$db'@'%' IDENTIFIED BY '${password//\'/\'\'}';
GRANT ALL PRIVILEGES ON \`$db\`.* TO '$db'@'%';
"
done

docker exec -i mariadb sh -c 'export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"; exec mariadb -uroot' <<<"$sql"
echo "✅ Bases prêtes : gitea, nextcloud, vaultwarden"
