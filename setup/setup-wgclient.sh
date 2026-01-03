#!/usr/bin/env bash
set -euo pipefail

### =========================
### VOREINGESTELLTE VARIABLEN
### =========================

WG_IFACE="${WG_IFACE:-wg0}"
WG_ADDRESS="${WG_ADDRESS:-10.42.42.2/32}"
WG_DNS="${WG_DNS:-10.42.42.2,9.9.9.9,1.1.1.1}"
WG_ENDPOINT="${WG_ENDPOINT:-vpn.mq6.de:51820}"
WG_ALLOWED_IPS="${WG_ALLOWED_IPS:-0.0.0.0/0}"
WG_PEER_PUBKEY="${WG_PEER_PUBKEY:-yQz11UDxnkSf5ncHk9mj2/m825najgL1HDmMIzaJ0BI=}"
WG_KEEPALIVE="${WG_KEEPALIVE:-25}"

WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/${WG_IFACE}.conf"

### =========================
### HILFSFUNKTIONEN
### =========================

ask_if_empty() {
  local var_name="$1"
  local prompt="$2"
  local current_value="${!var_name:-}"

  if [[ -z "$current_value" ]]; then
    read -rp "$prompt: " current_value
    export "$var_name"="$current_value"
  fi
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Dieses Script muss als root laufen."
    exit 1
  fi
}

require_ubuntu() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
      echo "Dieses Script ist nur für Ubuntu Server gedacht (ID=ubuntu). Gefunden: ID=${ID:-unknown}"
      exit 1
    fi
  else
    echo "/etc/os-release fehlt. Kann OS nicht verifizieren."
    exit 1
  fi
}

install_wireguard() {
  echo "[*] Installiere WireGuard (Ubuntu/apt) …"

  if command -v wg &>/dev/null; then
    echo "[*] WireGuard ist bereits installiert."
    return
  fi

  apt update
  apt install -y wireguard wireguard-tools
}

generate_config() {
  echo "[*] Erzeuge WireGuard-Konfiguration …"

  mkdir -p "$WG_DIR"
  chmod 700 "$WG_DIR"

  ask_if_empty WG_IFACE "Interface-Name (z.B. wg0)"
  WG_CONF="${WG_DIR}/${WG_IFACE}.conf"

  ask_if_empty WG_ADDRESS "Interface Address (z.B. 10.42.42.2/32)"
  ask_if_empty WG_DNS "DNS Server (comma-separated)"
  ask_if_empty WG_PEER_PUBKEY "Peer PublicKey"
  ask_if_empty WG_ENDPOINT "Endpoint (host:port)"
  ask_if_empty WG_ALLOWED_IPS "AllowedIPs"
  ask_if_empty WG_KEEPALIVE "PersistentKeepalive"

  umask 077
  PRIVATE_KEY="$(wg genkey)"
  PUBLIC_KEY="$(printf '%s' "$PRIVATE_KEY" | wg pubkey)"

  cat > "$WG_CONF" <<EOF
[Interface]
PrivateKey = $PRIVATE_KEY
# PublicKey = $PUBLIC_KEY
Address = $WG_ADDRESS
DNS = $WG_DNS

[Peer]
PublicKey = $WG_PEER_PUBKEY
Endpoint = $WG_ENDPOINT
AllowedIPs = $WG_ALLOWED_IPS
PersistentKeepalive = $WG_KEEPALIVE
EOF

  chmod 600 "$WG_CONF"

  echo "[*] Fertig: $WG_CONF"
  echo "[*] PublicKey (Client, für Server-Config): $PUBLIC_KEY"
}

start_and_enable() {
  ask_if_empty WG_IFACE "Interface-Name (z.B. wg0)"
  WG_CONF="${WG_DIR}/${WG_IFACE}.conf"

  if [[ ! -f "$WG_CONF" ]]; then
    echo "Config nicht gefunden: $WG_CONF"
    echo "Erst Menüpunkt 2 ausführen."
    exit 1
  fi

  echo "[*] Aktiviere Autostart: wg-quick@${WG_IFACE}"
  systemctl enable "wg-quick@${WG_IFACE}"

  echo "[*] Starte WireGuard: wg-quick@${WG_IFACE}"
  systemctl start "wg-quick@${WG_IFACE}"

  echo "[*] Status:"
  systemctl --no-pager -l status "wg-quick@${WG_IFACE}" || true

  echo "[*] Kurzcheck (wg show):"
  wg show || true
}

### =========================
### MENÜ
### =========================

require_root
require_ubuntu

echo "=============================="
echo " WireGuard Client Setup (Ubuntu)"
echo "=============================="
echo "1) WireGuard installieren"
echo "2) Config erstellen"
echo "3) WireGuard starten + Autostart einrichten (wg-quick@iface)"
read -rp "Auswahl: " CHOICE

case "$CHOICE" in
  1)
    install_wireguard
    ;;
  2)
    install_wireguard
    generate_config
    ;;
  3)
    install_wireguard
    start_and_enable
    ;;
  *)
    echo "Ungültige Auswahl."
    exit 1
    ;;
esac
