# mailcow Backup Script v3.0.0 - Major Release (Deutsch)

Ich freue mich, **mailcow Backup Script v3.0.0** zu veroeffentlichen.
Dieses Major-Release bringt Internationalisierung, neue Upload-Ziele und ein sichereres Update-Setup.

## Highlights

- Internationalisierte Skripte und Ausgaben fuer bessere Zusammenarbeit
- Bilinguale Dokumentation (Deutsch und Englisch)
- Neue Upload-Methoden: NAS und S3-kompatible Provider
- Two-Phase-Update: erst Selbst-Update, dann komplettes Repository-Update
- Automatische Reparatur von systemd-Service-Pfaden nach Updates
- Verbesserte Dependency-Pruefung mit optionaler Installation

## Wichtige Aenderungen

### Neue Features

- NAS-Upload fuer gemountete SMB/CIFS- und NFS-Pfade
- S3-Upload via AWS CLI (AWS S3 und S3-kompatible Dienste)
- Branch-aware Update-Verhalten mit stabiler/development Trennung
- Status-Flag-Workflow, damit Uploads nur nach erfolgreichem Backup starten

### Verbesserungen

- Besseres Retention-Handling und Timestamp-Backups
- Robustere Fehlerbehandlung in Backup- und Upload-Skripten
- Setup deckt jetzt alle Upload-Methoden ab

### Breaking Changes

- Skript-Ausgaben sind jetzt standardisiert auf Englisch
- Backup-Dateinamenformat: `mailcow-backup_YYYY-MM-DD_HH-MM-SS.tar.gz`
- Backup-Skript wurde nach `Backup/mailcow-backup.sh` verschoben

## Upgrade von V2 auf V3

Wichtiger Hinweis: In der urspruenglichen V2-Branch gab es keine `update.sh`.
Deshalb ist fuer alte V2-Installationen ein Bootstrap-Schritt noetig, bevor ein Branch-Upgrade per Flag moeglich ist.

Danach holt `git pull` grundsaetzlich auch neue Dateien. Ein manuelles Kopieren ist dann normalerweise nicht mehr noetig.

Einmaliger Bootstrap fuer V2-Installationen ohne `update.sh`:

```bash
cd /root/mailcow-backup
curl -fsSL https://raw.githubusercontent.com/the1andoni/mailcow-backup/V2-LEGACY/update.sh -o update.sh
chmod +x update.sh
sudo ./update.sh --v3
```

Alternative (sauberster Weg): Neu klonen und Konfiguration uebernehmen:

```bash
git clone -b V3 https://github.com/the1andoni/mailcow-backup.git mailcow-backup-v3
cd mailcow-backup-v3
```

## Unterstuetzte Upload-Ziele

- WebDAV (z. B. Nextcloud, ownCloud, HiDrive)
- FTP/SFTP
- NAS (gemountetes SMB/CIFS oder NFS)
- S3-kompatible Provider (AWS S3, Wasabi, MinIO, Backblaze B2, etc.)

## Release Assets

- Debian-Paket: `mailcow-backup_3.0.0_all.deb`
- Source via Git tags and branches

## Links

- Release Notes: `RELEASE_NOTES_V3.md`
- Stable branch: <https://github.com/the1andoni/mailcow-backup/tree/V3>
- Releases: <https://github.com/the1andoni/mailcow-backup/releases>

## Danke

Danke an alle, die Feedback gegeben und das Projekt verbessert haben.
