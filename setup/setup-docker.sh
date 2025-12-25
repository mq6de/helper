#!/usr/bin/env bash
set -euo pipefail

# Docker Install (Ubuntu) – only if Docker isn't installed
# Uses Docker's official APT repo + GPG key, then verifies via systemd + hello-world.

log()  { printf '\n[+] %s\n' "$*"; }
warn() { printf '\n[!] %s\n' "$*" >&2; }
die()  { printf '\n[✗] %s\n' "$*" >&2; exit 1; }

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Bitte als root ausführen (oder: sudo $0)."
  fi
}

docker_installed() {
  command -v docker >/dev/null 2>&1
}

cleanup_hello_world() {
  # Remove hello-world container/image if present; ignore errors
  docker rm -f hello-world >/dev/null 2>&1 || true
  docker image rm -f hello-world >/dev/null 2>&1 || true
}

main() {
  need_root

  if docker_installed; then
    log "Docker ist bereits installiert ($(docker --version)). Nichts zu tun."
    exit 0
  fi

  log "APT update + prerequisites (ca-certificates, curl) ..."
  apt update
  apt install -y ca-certificates curl

  log "Keyring-Verzeichnis anlegen ..."
  install -m 0755 -d /etc/apt/keyrings

  log "Docker GPG Key holen ..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  log "Docker APT Repo eintragen ..."
  UBUNTU_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  if [[ -z "${UBUNTU_CODENAME}" ]]; then
    die "Konnte UBUNTU_CODENAME/VERSION_CODENAME nicht ermitteln."
  fi

  tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  log "APT update (mit Docker Repo) ..."
  apt update

  log "Docker Engine + Plugins installieren ..."
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  log "Docker Service aktivieren + starten ..."
  systemctl enable --now docker

  log "Check: systemctl status docker (kurz) ..."
  if ! systemctl is-active --quiet docker; then
    warn "Docker Dienst ist NICHT active. Voller Status:"
    systemctl status docker --no-pager || true
    die "Docker Dienst läuft nicht."
  fi
  systemctl status docker --no-pager --lines=8

  log "Check: docker run hello-world ..."
  cleanup_hello_world
  if ! docker run --name hello-world --rm hello-world >/tmp/docker-hello-world.log 2>&1; then
    warn "hello-world fehlgeschlagen. Output:"
    sed -n '1,200p' /tmp/docker-hello-world.log >&2 || true
    die "Docker funktioniert nicht korrekt (hello-world)."
  fi

  log "Aufräumen (hello-world image/container) ..."
  cleanup_hello_world
  rm -f /tmp/docker-hello-world.log || true

  log "OK: Docker ist installiert und läuft."
  log "Versionen:"
  docker --version
  docker compose version || true
}

main "$@"