#!/bin/sh
set -e

CONFIG=/app/config/config.xml

sed -i \
  -e "s#\(serverName=\)\"[^\"]*\"#\1\"${XMAGE_SERVER_NAME:-minilab-xmage}\"#" \
  "$CONFIG"

exec java -Xmx1024m -jar /app/lib/mage-server-*.jar
