# setup scripts

Small helper scripts for Ubuntu servers.

Repository path: `github.com/mq6de/helper/main/setup`

## Available scripts

- `setup-autoupdate`
- `setup-docker.sh`
- `setup-sshsync.sh`
- `setup-wgclient.sh`

---

## setup-autoupdate

Configures Ubuntu unattended-upgrades with local override files and keeps packaged defaults intact.

### Run
```bash
curl -fsSL https://raw.githubusercontent.com/mq6de/helper/main/setup/setup-autoupdate | sudo bash
```

### Run with custom variables
```bash
curl -fsSL https://raw.githubusercontent.com/mq6de/helper/main/setup/setup-autoupdate | sudo env AUTO_REBOOT=no AUTOCLEAN_INTERVAL_DAYS=14 ENABLE_VERBOSE_APT=0 bash
```

### Variables
- `AUTO_REBOOT`  
  Enable or disable automatic reboot after updates.  
  Allowed values: `yes|no|true|false|1|0`  
  Default: `yes`

- `AUTO_REBOOT_TIME`  
  Reboot time in `HH:MM` format. Only used when `AUTO_REBOOT` is enabled.  
  Default: `03:00`

- `ENABLE_VERBOSE_APT`  
  Sets `APT::Periodic::Verbose`.  
  Allowed values: `0|1`  
  Default: `1`

- `AUTOCLEAN_INTERVAL_DAYS`  
  Sets `APT::Periodic::AutocleanInterval`.  
  Must be a non-negative integer.  
  Default: `7`

- `INSTALL_APT_LISTCHANGES`  
  Installs `apt-listchanges` together with `unattended-upgrades`.  
  Allowed values: `yes|no|true|false|1|0`  
  Default: `yes`

---

## setup-docker.sh

Installs Docker on Ubuntu.

### Run
```bash
curl -fsSL https://raw.githubusercontent.com/mq6de/helper/main/setup/setup-docker.sh | sudo bash
```

### Variables / parameters
This script currently does not use custom environment variables or required positional parameters.

---

## setup-sshsync.sh

Creates or reuses a local Linux user, fetches public SSH keys from a GitHub account, writes them to `authorized_keys`, and creates a systemd service + timer for periodic sync.

### Run with defaults
```bash
curl -fsSL https://raw.githubusercontent.com/mq6de/helper/main/setup/setup-sshsync.sh | sudo bash
```

### Run with custom parameters
```bash
curl -fsSL https://raw.githubusercontent.com/mq6de/helper/main/setup/setup-sshsync.sh | sudo bash -s -- YOUR_GITHUB_USERNAME yourlocaluser 30min
```

### Parameters
This script uses **positional parameters**, not environment variables.

- `$1` = `GitHub username`  
  The GitHub account whose public keys will be fetched from `https://github.com/<user>.keys`  
  Default: `GITHUB_USERNAME`

- `$2` = `local Linux user`  
  The local account that should receive the SSH keys  
  Default: `user`

- `$3` = `sync interval`  
  The systemd timer interval, for example `15min`, `30min`, `1h`, or `6h`  
  Default: `30min`

---

## setup-wgclient.sh

Installs WireGuard on Ubuntu and generates a client configuration.

### Run
```bash
curl -fsSL https://raw.githubusercontent.com/mq6de/helper/main/setup/setup-wgclient.sh | sudo bash
```

### Run with custom variables
```bash
curl -fsSL https://raw.githubusercontent.com/mq6de/helper/main/setup/setup-wgclient.sh | sudo env WG_IFACE=wg0 WG_ADDRESS=10.42.42.2/32 WG_DNS=10.42.42.2,9.9.9.9,1.1.1.1 WG_ENDPOINT=vpn.example.com:51820 WG_ALLOWED_IPS=0.0.0.0/0 WG_PEER_PUBKEY='REPLACE_WITH_SERVER_PUBLIC_KEY' WG_KEEPALIVE=25 bash
```

### Variables
- `WG_IFACE`  
  WireGuard interface name  
  Default: `wg0`

- `WG_ADDRESS`  
  Client tunnel IP in CIDR notation  
  Default: `10.42.42.2/32`

- `WG_DNS`  
  DNS servers, comma-separated  
  Default: `10.42.42.2,9.9.9.9,1.1.1.1`

- `WG_ENDPOINT`  
  Remote WireGuard endpoint in `host:port` format  
  Default: `vpn.mq6.de:51820`

- `WG_ALLOWED_IPS`  
  Routes sent through the tunnel  
  Default: `0.0.0.0/0`

- `WG_PEER_PUBKEY`  
  Server/public peer key  
  Must match your WireGuard server configuration

- `WG_KEEPALIVE`  
  Persistent keepalive in seconds  
  Default: `25`

If one of these values is empty, the script may ask for it interactively.

---

## Notes

- These scripts are intended mainly for Ubuntu hosts.
- The one-liners above use `curl` and pipe directly into `sudo bash`.
- That is convenient, but reviewing the script before running it is recommended for production systems.

## Safer alternative

Download first, review, then execute:

```bash
curl -fsSL -o /tmp/script.sh <RAW_URL> && less /tmp/script.sh && sudo bash /tmp/script.sh
```
