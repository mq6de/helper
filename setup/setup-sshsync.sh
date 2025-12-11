#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

###############################################################################
# Konfiguration
###############################################################################
# Fallback-Defaults (werden genutzt, wenn keine Parameter übergeben werden)
GITHUB_USER_DEFAULT="GITHUB_USERNAME"
LOCAL_USER_DEFAULT="user"        # Linux-User, der per SSH-Key rein darf
SYNC_INTERVAL_DEFAULT="30min"    # systemd-Intervall, z.B. "15min", "1h", "6h"

# Parameter:
#   $1 = GitHub Username
#   $2 = lokaler Linux-User
#   $3 = Sync-Intervall für systemd-Timer
GITHUB_USER="${1:-$GITHUB_USER_DEFAULT}"
LOCAL_USER="${2:-$LOCAL_USER_DEFAULT}"
SYNC_INTERVAL="${3:-$SYNC_INTERVAL_DEFAULT}"

###############################################################################
# Root-Check
###############################################################################
if [ "$EUID" -ne 0 ]; then
    echo "Dieses Script muss als root laufen." >&2
    exit 1
fi

###############################################################################
# 1) User prüfen/erstellen
###############################################################################
if id "$LOCAL_USER" >/dev/null 2>&1; then
    echo "User '$LOCAL_USER' existiert bereits."
else
    echo "Erstelle User '$LOCAL_USER'..."
    useradd -m -s /bin/bash "$LOCAL_USER"
    # Falls der User wirklich *nur* per SSH-Key genutzt werden soll,
    # kann man das Passwort zusätzlich sperren:
    # passwd -l "$LOCAL_USER"
fi

USER_HOME="$(getent passwd "$LOCAL_USER" | cut -d: -f6)"
if [ -z "$USER_HOME" ]; then
    echo "Konnte Home-Verzeichnis für $LOCAL_USER nicht bestimmen." >&2
    exit 1
fi

###############################################################################
# 2) Helper-Script zum Aktualisieren der authorized_keys von GitHub
###############################################################################
UPDATE_SCRIPT="/usr/local/sbin/update-github-keys.sh"

cat >"$UPDATE_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <GITHUB_USER> <LOCAL_USER>" >&2
    exit 1
fi

GITHUB_USER="$1"
LOCAL_USER="$2"

USER_HOME="$(getent passwd "$LOCAL_USER" | cut -d: -f6)"
if [ -z "$USER_HOME" ]; then
    echo "Konnte Home-Verzeichnis für $LOCAL_USER nicht bestimmen." >&2
    exit 1
fi

SSH_DIR="$USER_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"

# Nur als root chownen, sonst knallt das, falls Service später mit User-Rechten läuft
if [ "$(id -u)" -eq 0 ]; then
    chown "$LOCAL_USER:$LOCAL_USER" "$SSH_DIR"
fi
chmod 700 "$SSH_DIR"

echo "Starte Update der authorized_keys für ${LOCAL_USER} von GitHub:${GITHUB_USER}..."

# Fetch-Command bestimmen
if command -v curl >/dev/null 2>&1; then
    FETCH_CMD=(curl -fsSL "https://github.com/${GITHUB_USER}.keys")
elif command -v wget >/dev/null 2>&1; then
    FETCH_CMD=(wget -qO- "https://github.com/${GITHUB_USER}.keys")
else
    echo "ERROR: weder curl noch wget vorhanden." >&2
    exit 1
fi

TMP_FILE="$(mktemp)"

if ! "${FETCH_CMD[@]}" >"$TMP_FILE"; then
    echo "ERROR: Download der GitHub-Keys fehlgeschlagen." >&2
    rm -f "$TMP_FILE"
    exit 1
fi

# Minimaler Sanity-Check
if ! grep -qE '^ssh-(rsa|ed25519|ecdsa)' "$TMP_FILE"; then
    echo "ERROR: keine gültigen SSH-Public-Keys in GitHub-Response gefunden." >&2
    rm -f "$TMP_FILE"
    exit 1
fi

KEY_COUNT="$(grep -cE '^ssh-(rsa|ed25519|ecdsa)' "$TMP_FILE" || true)"

install -m 600 "$TMP_FILE" "$AUTH_KEYS"
if [ "$(id -u)" -eq 0 ]; then
    chown "$LOCAL_USER:$LOCAL_USER" "$AUTH_KEYS"
fi
rm -f "$TMP_FILE"

echo "OK: authorized_keys für ${LOCAL_USER} aktualisiert (${KEY_COUNT} Keys von GitHub:${GITHUB_USER})."
EOF

chmod 755 "$UPDATE_SCRIPT"

###############################################################################
# 3) systemd Service + Timer für periodische Aktualisierung
###############################################################################
SERVICE_NAME="github-keys-${LOCAL_USER}.service"
TIMER_NAME="github-keys-${LOCAL_USER}.timer"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
TIMER_PATH="/etc/systemd/system/${TIMER_NAME}"

cat >"$SERVICE_PATH" <<EOF
[Unit]
Description=Update SSH authorized_keys für ${LOCAL_USER} von GitHub (${GITHUB_USER})
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=${UPDATE_SCRIPT} ${GITHUB_USER} ${LOCAL_USER}
StandardOutput=journal
StandardError=journal
EOF

cat >"$TIMER_PATH" <<EOF
[Unit]
Description=Periodische Aktualisierung der SSH authorized_keys für ${LOCAL_USER} von GitHub

[Timer]
OnBootSec=5min
OnUnitActiveSec=${SYNC_INTERVAL}
Persistent=true
Unit=${SERVICE_NAME}

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now "$TIMER_NAME"

###############################################################################
# 4) Initialer SSH-Key-Sync
###############################################################################
echo "Führe initialen Key-Sync aus..."
"$UPDATE_SCRIPT" "$GITHUB_USER" "$LOCAL_USER"

###############################################################################
# 5) Passwortanmeldung für diesen User via SSH deaktivieren (Key-only)
###############################################################################
SSHD_DROPIN_DIR="/etc/ssh/sshd_config.d"
DROPIN_FILE="${SSHD_DROPIN_DIR}/90-${LOCAL_USER}-nopassword.conf"

if [ -d "$SSHD_DROPIN_DIR" ]; then
    cat >"$DROPIN_FILE" <<EOF
Match User ${LOCAL_USER}
    PasswordAuthentication no
    KbdInteractiveAuthentication no
EOF
    echo "SSH-Drop-In für User ${LOCAL_USER} erstellt: ${DROPIN_FILE}"
else
    echo "WARNUNG: /etc/ssh/sshd_config.d existiert nicht. Bitte manuell in /etc/ssh/sshd_config konfigurieren:"
    echo ""
    echo "Match User ${LOCAL_USER}"
    echo "    PasswordAuthentication no"
    echo "    KbdInteractiveAuthentication no"
    echo ""
fi

# SSH neu laden
if systemctl reload ssh 2>/dev/null; then
    echo "ssh Dienst neu geladen."
elif systemctl reload sshd 2>/dev/null; then
    echo "sshd Dienst neu geladen."
else
    echo "Konnte ssh/sshd nicht automatisch reloaden – bitte manuell prüfen."
fi

echo "Setup abgeschlossen. Logs: journalctl -u ${SERVICE_NAME} -u ${TIMER_NAME}"