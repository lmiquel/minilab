#!/bin/sh
# =============================================================================
#  firewall.sh — Règles iptables du tunnel, appelé par PostUp/PostDown de
#  wireguard : `sh /minilab/firewall.sh up|down %i`.
#  Admins : accès complet. Invités : SWAG, jeux, DNS Pi-hole et internet.
# =============================================================================
set -eu

WG="${2:-wg0}"
WG_IP=10.13.13.1
ADMINS=$(echo "${WG_ADMIN_PEERS:-}" | tr ',' ' ')
GUEST_TCP="80,443,25565"
GUEST_UDP="2456:2458,16261:16262"
PIHOLE=172.20.0.3
HOST=172.20.0.1
MARIADB=172.20.0.40
GITEA=172.20.0.43

del() {
  while iptables "$@" 2>/dev/null; do :; done
}

down() {
  del -D INPUT -i "$WG" -j MINILAB_IN
  del -D FORWARD -i "$WG" -j MINILAB_FWD
  del -D FORWARD -i "$WG" -j ACCEPT
  del -D FORWARD -o "$WG" -j ACCEPT
  del -t nat -D PREROUTING -i "$WG" -d "$WG_IP" -j MINILAB_DNAT
  del -t nat -D POSTROUTING -o eth+ -j MASQUERADE
  for chain in MINILAB_IN MINILAB_FWD; do
    iptables -F "$chain" 2>/dev/null || true
    iptables -X "$chain" 2>/dev/null || true
  done
  iptables -t nat -F MINILAB_DNAT 2>/dev/null || true
  iptables -t nat -X MINILAB_DNAT 2>/dev/null || true
}

up() {
  down

  iptables -A FORWARD -o "$WG" -j ACCEPT
  iptables -t nat -A POSTROUTING -o eth+ -j MASQUERADE

  iptables -t nat -N MINILAB_DNAT
  iptables -t nat -A PREROUTING -i "$WG" -d "$WG_IP" -j MINILAB_DNAT
  iptables -t nat -A MINILAB_DNAT -p tcp --dport 2222 -j DNAT --to-destination "$GITEA:22"
  for ip in $ADMINS; do
    iptables -t nat -A MINILAB_DNAT -s "$ip" -p tcp --dport 22 -j DNAT --to-destination "$HOST:22"
    iptables -t nat -A MINILAB_DNAT -s "$ip" -p tcp --dport 3306 -j DNAT --to-destination "$MARIADB:3306"
  done

  iptables -N MINILAB_FWD
  iptables -A FORWARD -i "$WG" -j MINILAB_FWD
  iptables -A MINILAB_FWD -m conntrack --ctstate ESTABLISHED,RELATED,DNAT -j ACCEPT
  for ip in $ADMINS; do
    iptables -A MINILAB_FWD -s "$ip" -j ACCEPT
  done
  iptables -A MINILAB_FWD -d "$PIHOLE" -p udp --dport 53 -j ACCEPT
  iptables -A MINILAB_FWD -d "$PIHOLE" -p tcp --dport 53 -j ACCEPT
  for net in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16; do
    iptables -A MINILAB_FWD -d "$net" -j DROP
  done
  iptables -A MINILAB_FWD -j ACCEPT

  iptables -N MINILAB_IN
  iptables -A INPUT -i "$WG" -j MINILAB_IN
  iptables -A MINILAB_IN -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  for ip in $ADMINS; do
    iptables -A MINILAB_IN -s "$ip" -j ACCEPT
  done
  iptables -A MINILAB_IN -p tcp -m multiport --dports "$GUEST_TCP" -j ACCEPT
  iptables -A MINILAB_IN -p udp -m multiport --dports "$GUEST_UDP" -j ACCEPT
  iptables -A MINILAB_IN -p icmp -j ACCEPT
  iptables -A MINILAB_IN -j DROP
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 up|down [interface]" >&2; exit 1 ;;
esac
