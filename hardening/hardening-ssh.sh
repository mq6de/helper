#!/usr/bin/env bash
set -euo pipefail

############################################
# Konfiguration (Defaults = aktiviert)
############################################
DISABLE_ROOT_LOGIN=true
DISABLE_PASSWORD_AUTH=true

SSHD_CONFIG="/etc/ssh/sshd_config"

############################################
# Helper
############################################
fail() {
  echo "[FEHLER] $1" >&2
  exit 1
}

ok() {
  echo "[OK] $1"
}

require_root() {
  [[ $EUID -eq 0 ]] || fail "Script muss als root laufen"
}

set_sshd_option() {
  local key="$1"
  local value="$2"

  if grep -Eq "^[#[:space:]]*${key}\b" "$SSHD_CONFIG"; then
    sed -i "s|^[#[:space:]]*${key}\b.*|${key} ${value}|g" "$SSHD_CONFIG"
  else
    echo "${key} ${value}" >>"$SSHD_CONFIG"
  fi
}

############################################
# Main
############################################
require_root

echo "[*] Konfiguriere OpenSSH …"

if [[ "$DISABLE_ROOT_LOGIN" == "true" ]]; then
  set_sshd_option "PermitRootLogin" "no"
  ok "PermitRootLogin deaktiviert"
else
  set_sshd_option "PermitRootLogin" "yes"
  ok "PermitRootLogin aktiviert"
fi

if [[ "$DISABLE_PASSWORD_AUTH" == "true" ]]; then
  set_sshd_option "PasswordAuthentication" "no"
  ok "PasswordAuthentication deaktiviert"
else
  set_sshd_option "PasswordAuthentication" "yes"
  ok "PasswordAuthentication aktiviert"
fi

############################################
# Validierung
############################################
echo "[*] Prüfe sshd Konfiguration …"
sshd -t || fail "sshd_config syntaktisch FEHLERHAFT"

systemctl reload ssh || fail "ssh reload fehlgeschlagen"

############################################
# Laufzeitprüfung
############################################
RUNTIME_ROOT=$(sshd -T | awk '/^permitrootlogin/{print $2}')
RUNTIME_PW=$(sshd -T | awk '/^passwordauthentication/{print $2}')

[[ "$DISABLE_ROOT_LOGIN" == "true" && "$RUNTIME_ROOT" != "no" ]] && fail "PermitRootLogin Laufzeitwert inkorrekt"
[[ "$DISABLE_PASSWORD_AUTH" == "true" && "$RUNTIME_PW" != "no" ]] && fail "PasswordAuthentication Laufzeitwert inkorrekt"

############################################
# Ergebnis
############################################
echo "========================================"
ok "SSH-Härtung erfolgreich angewendet"
echo "PermitRootLogin        = $RUNTIME_ROOT"
echo "PasswordAuthentication = $RUNTIME_PW"
echo "========================================"