# helper

# /setup/setup-sshsync.sh

Dieses Script richtet einen lokalen Linux-User für SSH-Key-Login ein und synchronisiert dessen `authorized_keys` automatisch aus den im GitHub-Profil hinterlegten Public Keys. Ein systemd-Timer aktualisiert die Keys regelmäßig.

## Funktionen

- legt den gewünschten User an, falls er noch nicht existiert  
- lädt GitHub-Public-Keys und schreibt sie in `~/.ssh/authorized_keys`  
- installiert bei Bedarf `curl` oder `wget`  
- deaktiviert Passwort-Login **nur für SSH** (kein `passwd -l`)  
- richtet systemd-Service und Timer zur automatischen Aktualisierung ein  
- schreibt Logs ausschließlich ins systemd-Journal

## Ausführen

```bash
sudo ./install-github-authorized-keys-sync.sh
```

## Logs ansehen

```bash
journalctl -u github-keys-<username>.service
journalctl -u github-keys-<username>.timer
```