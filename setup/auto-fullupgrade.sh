#!/bin/bash
set -e

# =========================
# Einstellungen
# =========================

UPDATE_TIME="03:00:00"
AUTO_REBOOT="yes"        # yes / no
AUTO_REMOVE="yes"        # yes / no
PURGE_CONFIGS="yes"      # yes / no

# =========================

cat >/usr/local/sbin/daily-upgrade.sh <<EOF
#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get full-upgrade -y

if [ "$AUTO_REMOVE" = "yes" ]; then
    if [ "$PURGE_CONFIGS" = "yes" ]; then
        apt-get autoremove --purge -y
    else
        apt-get autoremove -y
    fi
fi

if [ "$AUTO_REBOOT" = "yes" ] && [ -f /var/run/reboot-required ]; then
    systemctl reboot
fi
EOF

chmod +x /usr/local/sbin/daily-upgrade.sh

cat >/etc/systemd/system/daily-upgrade.service <<'EOF'
[Unit]
Description=Daily automatic full upgrade

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/daily-upgrade.sh
EOF

cat >/etc/systemd/system/daily-upgrade.timer <<EOF
[Unit]
Description=Daily automatic upgrade

[Timer]
OnCalendar=*-*-* $UPDATE_TIME
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now daily-upgrade.timer

echo
echo "Autoupdates aktiviert:"
echo "  Zeit:       $UPDATE_TIME"
echo "  Reboot:     $AUTO_REBOOT"
echo "  Autoremove: $AUTO_REMOVE"
echo "  Purge:      $PURGE_CONFIGS"
echo
systemctl list-timers daily-upgrade.timer --no-pager
