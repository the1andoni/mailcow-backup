## Deutsch

Ich freue mich, **mailcow Backup Script v3.0.0** zu veröffentlichen.
Dieses Major-Release bringt Internationalisierung, neue Upload-Ziele und ein sichereres Update-Setup.

## Highlights

- Internationalisierte Skripte und Ausgaben für bessere Zusammenarbeit
- Bilinguale Dokumentation (Deutsch und Englisch)
- Neue Upload-Methoden: NAS und S3-kompatible Provider
- Two-Phase-Update: erst Selbst-Update, dann komplettes Repository-Update
- Automatische Reparatur von systemd-Service-Pfaden nach Updates
- Verbesserte Dependency-Prüfung mit optionaler Installation

## Wichtige Änderungen

### Neue Features

- NAS-Upload für gemountete SMB/CIFS- und NFS-Pfade
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

Wichtiger Hinweis: In der ursprünglichen V2-Branch gab es keine `update.sh`.
Deshalb ist für alte V2-Installationen ein Bootstrap-Schritt nötig, bevor ein Branch-Upgrade per Flag möglich ist.

Danach holt `git pull` grundsätzlich auch neue Dateien. Ein manuelles Kopieren ist dann normalerweise nicht mehr nötig.

Einmaliger Bootstrap für V2-Installationen ohne `update.sh`:

```bash
cd /root/mailcow-backup
curl -fsSL https://raw.githubusercontent.com/the1andoni/mailcow-backup/V2-LEGACY/update.sh -o update.sh
chmod +x update.sh
sudo ./update.sh --v3
```

Alternative (sauberster Weg): Neu klonen und Konfiguration übernehmen:

```bash
git clone -b V3 https://github.com/the1andoni/mailcow-backup.git mailcow-backup-v3
cd mailcow-backup-v3
```

## Unterstützte Upload-Ziele

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

---

## English

I am happy to announce **mailcow Backup Script v3.0.0**.
This major release introduces internationalization, new upload targets, and a safer update workflow.

## Highlights

- Internationalized scripts and outputs for better collaboration
- Bilingual documentation (German and English)
- New upload methods: NAS and S3-compatible providers
- Two-phase update flow with self-update first, then full repository update
- Automatic systemd service path repair after updates
- Better dependency validation with optional install flow

## Notable Changes

### New Features

- NAS upload support for mounted SMB/CIFS and NFS paths
- S3 upload support via AWS CLI (AWS S3 and S3-compatible services)
- Branch-aware update behavior with clear stable/development tracks
- Status-flag workflow to avoid uploads before backup completion

### Improvements

- Better retention handling and timestamped backup naming
- More robust error handling across backup and upload scripts
- Setup workflow now covers all upload methods

### Breaking Changes

- Script outputs are now standardized in English
- Backup naming format updated to `mailcow-backup_YYYY-MM-DD_HH-MM-SS.tar.gz`
- Backup script moved to `Backup/mailcow-backup.sh`

## Upgrade from V2 to V3

Important note: the original V2 branch did not include an `update.sh`.
For old V2 installations, a bootstrap step is required before branch switching with flags is possible.

After that, `git pull` normally fetches new files as well, so manual copying is usually no longer required.

One-time bootstrap for V2 installations without `update.sh`:

```bash
cd /root/mailcow-backup
curl -fsSL https://raw.githubusercontent.com/the1andoni/mailcow-backup/V2-LEGACY/update.sh -o update.sh
chmod +x update.sh
sudo ./update.sh --v3
```

Alternative (cleanest path): clone fresh and migrate your configuration:

```bash
git clone -b V3 https://github.com/the1andoni/mailcow-backup.git mailcow-backup-v3
cd mailcow-backup-v3
```

## Supported Upload Targets

- WebDAV (for example Nextcloud, ownCloud, HiDrive)
- FTP/SFTP
- NAS (mounted SMB/CIFS or NFS)
- S3-compatible providers (AWS S3, Wasabi, MinIO, Backblaze B2, and others)

## Release Assets

- Debian package: `mailcow-backup_3.0.0_all.deb`
- Source via Git tags and branches

## Links

- Release Notes: `RELEASE_NOTES_V3.md`
- Stable branch: <https://github.com/the1andoni/mailcow-backup/tree/V3>
- Releases: <https://github.com/the1andoni/mailcow-backup/releases>

## Thank You

Thanks to everyone who shared feedback and helped improve the project.
