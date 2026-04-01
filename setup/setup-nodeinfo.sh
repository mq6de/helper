#!/usr/bin/env bash
set -u

# --- helpers ---------------------------------------------------------------

trim() {
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

bytes_to_human() {
  local bytes="$1"
  awk -v b="$bytes" '
    function human(x) {
      s="B KB MB GB TB PB"
      split(s, arr, " ")
      i=1
      while (x >= 1024 && i < 6) {
        x /= 1024
        i++
      }
      if (x >= 10) printf "%.0f%s", x, arr[i]
      else printf "%.1f%s", x, arr[i]
    }
    BEGIN { human(b) }
  '
}

# --- basic system info -----------------------------------------------------

timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"
fqdn="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
current_user="$(whoami 2>/dev/null || echo unknown)"

# OS version
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  os_version="${PRETTY_NAME:-${NAME:-Linux}}"
else
  os_version="$(uname -srm)"
fi

# --- CPU -------------------------------------------------------------------

cpu_arch="$(uname -m 2>/dev/null || echo unknown)"
cpu_model="$(awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
[[ -z "${cpu_model:-}" ]] && cpu_model="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
[[ -z "${cpu_model:-}" ]] && cpu_model="unknown"

cpu_cores="$(nproc 2>/dev/null || echo '?')"

cpu_mhz="$(awk -F: '/cpu MHz/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
if [[ -n "${cpu_mhz:-}" ]]; then
  cpu_ghz="$(awk -v mhz="$cpu_mhz" 'BEGIN { printf "%.1f", mhz/1000 }')"
else
  cpu_ghz="?"
fi

cpu_info="${cpu_cores} Core @ ${cpu_ghz}GHz, ${cpu_arch}"

# --- RAM -------------------------------------------------------------------

ram_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)"
if [[ -n "${ram_kb:-}" ]]; then
  ram_human="$(awk -v kb="$ram_kb" 'BEGIN {
    gb = kb / 1024 / 1024
    if (gb >= 10) printf "%.0fGB", gb
    else printf "%.1fGB", gb
  }')"
else
  ram_human="unknown"
fi

# --- Storage ----------------------------------------------------------------

storage_info="$(
  lsblk -b -dn -o NAME,SIZE,TYPE 2>/dev/null | \
  awk '$3=="disk" || $3=="part" {print $1 ":" $2}' | \
  while IFS=: read -r name size; do
    printf "%s: %s\n" "$name" "$(bytes_to_human "$size")"
  done | paste -sd ', ' -
)"
[[ -z "${storage_info:-}" ]] && storage_info="unknown"

# --- Networking -------------------------------------------------------------

default_if="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
default_gw4="$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')"

ipv4_addr="$(
  if [[ -n "${default_if:-}" ]]; then
    ip -4 addr show dev "$default_if" 2>/dev/null | awk '/inet / {print $2; exit}'
  fi
)"
[[ -z "${ipv4_addr:-}" ]] && ipv4_addr="none"
[[ -z "${default_gw4:-}" ]] && default_gw4="none"

dns_servers="$(
  awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | paste -sd ', ' -
)"
[[ -z "${dns_servers:-}" ]] && dns_servers="none"

ipv6_addrs="$(
  ip -6 addr show scope global 2>/dev/null | awk '/inet6 / {print $2}' | paste -sd ', ' -
)"
[[ -z "${ipv6_addrs:-}" ]] && ipv6_addrs="none"

# --- Virtualization ---------------------------------------------------------

virt="Bare Metal / unknown"

if command -v systemd-detect-virt >/dev/null 2>&1; then
  virt_detect="$(systemd-detect-virt 2>/dev/null)"
  if systemd-detect-virt -q --container 2>/dev/null; then
    virt="Container: ${virt_detect:-unknown}"
  elif systemd-detect-virt -q 2>/dev/null; then
    virt="VM: ${virt_detect:-unknown}"
  else
    virt="Bare Metal"
  fi
elif grep -qa container=lxc /proc/1/environ 2>/dev/null; then
  virt="Container: lxc"
elif [[ -f /.dockerenv ]]; then
  virt="Container: docker"
fi

# --- output ----------------------------------------------------------------

cat <<EOF
[$fqdn]
Timestamp : $timestamp
OS        : $os_version
CPU       : $cpu_info
RAM       : $ram_human
Storage   : $storage_info
IPv4      : $ipv4_addr
Gateway   : $default_gw4
DNS       : $dns_servers
IPv6      : $ipv6_addrs
User      : $current_user
Virt      : $virt
EOF
