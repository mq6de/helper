#/setup/setup-sshsync.sh
Dieses Script richtet einen lokalen Linux-User für SSH-Key-Login ein und synchronisiert dessen `authorized_keys` automatisch aus den im GitHub-Profil hinterlegten Public Keys. Ein systemd-Timer aktualisiert die Keys regelmäßig.

## Funktionen

- legt den gewünschten User an, falls er noch nicht existiert  
- lädt GitHub-Public-Keys und schreibt sie in `~/.ssh/authorized_keys`  
- installiert bei Bedarf `curl` oder `wget`  
- deaktiviert Passwort-Login **nur für SSH** (kein `passwd -l`)  
- richtet systemd-Service und Timer zur automatischen Aktualisierung ein  
- schreibt Logs ausschließlich ins systemd-Journal

## Parameter

Die folgenden Parameter können beim Ausführen des Scripts übergeben werden. Werden keine Variablen übergeben, werden die festzulegenden Standardwerte aus dem Script verwendet.

Beipiel: Lokal abgelegt
```bash
./install-github-authorized-keys-sync.sh <github_user> <local_user> <sync_interval>
```

Beispiel: Download und ausführen: (Variablen anpassen!!)
```bash
curl -fsSL https://raw.githubusercontent.com/mq6de/helper/main/setup/setup-sshsync.sh | sudo bash -s GITHUB_USER user 30min
```

## Logs ansehen

```bash
journalctl -u github-keys-<username>.service
journalctl -u github-keys-<username>.timer
```

### Wichtiger Hinweis

Dies ist ein privates Projekt und ausschließlich für Testzwecke gedacht.  
Die Scripts sind **nicht für den produktiven Einsatz** vorgesehen.  
Es erfolgt **keine Haftung** für Schäden, Fehlfunktionen oder Sicherheitsprobleme, die aus der Nutzung entstehen.

## Notice

This is a private project intended solely for testing.  
The scripts is **not designed for production use**.  
No liability is assumed for any damage, malfunction, or security issues resulting from its use.