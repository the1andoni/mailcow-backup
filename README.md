# mailcow Backup Script V2

Ein Bash-Skript zur Sicherung von mailcow-Daten mit Unterstützung für WebDAV-, FTP/SFTP-, NAS- und S3-Uploads. Dieses Projekt ermöglicht es, automatisierte Backups zu erstellen, zu verschlüsseln und auf Remote-Server hochzuladen.

## Ordnerstruktur

```
mailcow-BackupV2/
├── setup.sh
├── update.sh
├── Backup/
│   └── mailcow-backup.sh
├── Dependencies/
│   ├── dependencies.txt
│   └── install_dependencies.sh
├── Configs/
│   └── (verschlüsselte Konfigurationsdateien)
└── Upload/
    ├── FTP-Upload.sh
    ├── NAS-Upload.sh
    ├── S3-Upload.sh
    └── WebDAV-Upload.sh
```

## Features

- **Automatisierte Backups**: Erstellt Backups von mailcow-Daten.
- **Verschlüsselung**: Konfigurationsdateien werden mit GPG verschlüsselt.
- **Flexible Upload-Optionen**: Unterstützt WebDAV, FTP/SFTP, NAS (LAN) und S3-kompatible Speicher.
- **Automatische Dependency-Prüfung**: Setup und Upload-Skripte überprüfen benötigte Tools und bieten Installation an.
- **Systemd-Timer-Integration**: Automatische Planung von Backups und Uploads.
- **Retention Management**: Löscht alte Backups lokal und remote basierend auf definierten Aufbewahrungszeiten.
- **Update-Mechanismus**: Automatische Updates mit Systemd-Service-Reparatur.

## Voraussetzungen

- **Betriebssystem**: Linux (Debian/Ubuntu empfohlen)
- **Grundlegende Abhängigkeiten** (für alle Funktionen):
  - `gpg` - GPG-Verschlüsselung
  - `tar` - Archivierung
  - `systemd` - Timer-Verwaltung

- **Upload-spezifische Abhängigkeiten**:
  - **WebDAV/FTP/SFTP**: `curl`
  - **S3**: `awscli` (AWS CLI)
  - **NAS**: `mountpoint` (meist vorinstalliert)

**Hinweis**: Das Setup-Skript prüft automatisch fehlende Abhängigkeiten und bietet deren Installation an.

## Installation

1. **Repository herunterladen**:

   Sie können das Repository mithilfe von GitClone einfach runterladen.

   ```bash
   git clone https://github.com/the1andoni/mailcow-backupV2.git 
   cd mailcow-backupV2
   ```
   
   Die Scripte werden automatisch beim Setup ausführbar gemacht.

   Alternativ steht ein Debian Packet zum Download zur Verfügung.

   ```bash
   wget https://github.com/the1andoni/mailcow-backupV2/releases/download/v2.0.0/mailcow-backup-v2.deb
   ```

2. **Abhängigkeiten installieren** (optional):

   Sie können die Abhängigkeiten vorab installieren oder das Setup-Skript automatisch prüfen und installieren lassen:

   ```bash
   sudo ./Dependencies/install_dependencies.sh
   ```

   Alternativ manuell:

   ```bash
   sudo xargs -a Dependencies/dependencies.txt apt install -y
   ```

3. **Setup ausführen**:

   Starten Sie das Setup-Skript, um die Konfigurationen zu erstellen und systemd-Timer einzurichten:

   ```bash
   sudo ./setup.sh
   ```

   **Das Setup-Skript durchläuft folgende Schritte**:
   - Prüft automatisch auf verfügbare Updates
   - Überprüft benötigte Abhängigkeiten für gewählte Upload-Methoden
   - Bietet Installation fehlender Tools an
   - Konfiguriert gewählte Backup-Methoden (WebDAV/FTP/SFTP/NAS/S3)
   - Richtet systemd-Timer für automatisierte Backups ein

## Automatisierte Backups & GPG-Passwort

Damit geplante Backups und Uploads ohne Interaktion funktionieren, wird das GPG-Passwort während des Setups automatisch in einer Datei (`/root/.mailcow-gpg-pass`) gespeichert.  
**Achtung:** Die Datei ist nur für root lesbar und wird vom Setup-Skript wie folgt angelegt:

```bash
echo "DEIN_GPG_PASSWORT" | sudo tee /root/.mailcow-gpg-pass > /dev/null
sudo chmod 600 /root/.mailcow-gpg-pass
```

Das Backup-Skript liest dieses Passwort automatisch ein und entschlüsselt damit die Konfiguration.  
**Hinweis:** Ändere das Passwort in dieser Datei nur, wenn du auch die Konfiguration neu verschlüsselst!

## Nutzung

- **Updates installieren**:

  ```bash
  sudo ./update.sh
  ```

  Das Update-Skript aktualisiert das Repository, macht alle Scripts ausführbar und repariert automatisch alle systemd-Services, falls nötig.

- **Backup manuell starten**:

  ```bash
  sudo ./Backup/mailcow-backup.sh
  ```

- **WebDAV-Upload manuell starten**:

  ```bash
  sudo ./Upload/WebDAV-Upload.sh
  ```

- **FTP/SFTP-Upload manuell starten**:

  ```bash
  sudo ./Upload/FTP-Upload.sh
  ```

- **NAS-Upload manuell starten**:

  ```bash
  sudo ./Upload/NAS-Upload.sh
  ```

- **S3-Upload manuell starten**:

  ```bash
  sudo ./Upload/S3-Upload.sh
  ```

- **Systemd-Timer für Backups verwalten**:
  - **Status überprüfen**:
    ```bash
    systemctl status mailcow-backup.timer
    ```
  - **Manuell starten**:
    ```bash
    systemctl start mailcow-backup.service
    ```
  - **Deaktivieren**:
    ```bash
    systemctl disable mailcow-backup.timer
    ```

- **Systemd-Timer für WebDAV-Upload verwalten**:
  - **Status überprüfen**:
    ```bash
    systemctl status mailcow-webdav-upload.timer
    ```
  - **Manuell starten**:
    ```bash
    systemctl start mailcow-webdav-upload.service
    ```
  - **Deaktivieren**:
    ```bash
    systemctl disable mailcow-webdav-upload.timer
    ```

- **Systemd-Timer für FTP/SFTP-Upload verwalten**:
  - **Status überprüfen**:
    ```bash
    systemctl status mailcow-ftp-upload.timer
    ```
  - **Manuell starten**:
    ```bash
    systemctl start mailcow-ftp-upload.service
    ```
  - **Deaktivieren**:
    ```bash
    systemctl disable mailcow-ftp-upload.timer
    ```

- **Systemd-Timer für NAS-Upload verwalten**:
  - **Status überprüfen**:
    ```bash
    systemctl status mailcow-nas-upload.timer
    ```
  - **Manuell starten**:
    ```bash
    systemctl start mailcow-nas-upload.service
    ```
  - **Deaktivieren**:
    ```bash
    systemctl disable mailcow-nas-upload.timer
    ```

- **Systemd-Timer für S3-Upload verwalten**:
  - **Status überprüfen**:
    ```bash
    systemctl status mailcow-s3-upload.timer
    ```
  - **Manuell starten**:
    ```bash
    systemctl start mailcow-s3-upload.service
    ```
  - **Deaktivieren**:
    ```bash
    systemctl disable mailcow-s3-upload.timer
    ```

## Konfiguration

Die Konfigurationsdateien werden während des Setups erstellt und verschlüsselt im Ordner `Configs` gespeichert. Sie enthalten sensible Informationen wie Zugangsdaten und sollten niemals unverschlüsselt gespeichert werden.

## Automatisierung

Das Setup-Skript richtet automatisch systemd-Timer ein, um Backups und Uploads regelmäßig auszuführen. Die Timer können mit den folgenden Befehlen verwaltet werden:

- **Backup-Timer**:
  ```bash
  systemctl status mailcow-backup.timer
  ```
- **FTP/SFTP-Upload-Timer**:
  ```bash
  systemctl status mailcow-ftp-upload.timer
  ```
- **WebDAV-Upload-Timer**:
  ```bash
  systemctl status mailcow-webdav-upload.timer
  ```
- **NAS-Upload-Timer**:
  ```bash
  systemctl status mailcow-nas-upload.timer
  ```
- **S3-Upload-Timer**:
  ```bash
  systemctl status mailcow-s3-upload.timer
  ```

## Upload-Methoden im Detail

### WebDAV
- HTTPS-basierter Upload
- Kompatibel mit Nextcloud, ownCloud, HiDrive, etc.
- **Benötigt**: `curl`, `gpg`

### FTP/SFTP
- **FTP**: Optional mit TLS und Zertifikat-Fingerabdruck
- **SFTP**: Sichere SSH-basierte Übertragung
- **Benötigt**: `curl`, `gpg`

### NAS (Network Storage)
- Lokales oder LAN-basiertes NAS
- Erwartet eingehängtes Verzeichnis (z. B. via SMB/CIFS oder NFS)
- **Benötigt**: `mountpoint`, `gpg`

### S3 (Cloud Storage)
- AWS S3 und S3-kompatible Dienste (Wasabi, MinIO, Backblaze B2)
- Lifecycle-Regeln für automatische Retention empfohlen
- **Benötigt**: `awscli`, `gpg`

## Sicherheit

- **Verschlüsselung**: Alle Konfigurationsdateien werden mit GPG (AES256) verschlüsselt.
- **Passwort-Verwaltung**: Das GPG-Passwort wird sicher in `/root/.mailcow-gpg-pass` abgelegt (nur für root lesbar).
- **FTP-TLS**: Optional mit Zertifikat-Pinning für sichere FTP-Verbindungen.
- **SFTP**: Nutzt SSH-Authentifizierung über `curl`.
- **Dependency-Checks**: Alle Skripte prüfen benötigte Tools vor Ausführung.

## Lizenz
Dieses Projekt steht unter der **CyberSpaceConsulting Public License v1.0**.  
Die vollständigen Lizenzbedingungen findest du in der [LICENSE](LICENSE)-Datei.

### Wichtige Punkte der Lizenz:
1. **Keine Weiterveräußerung oder öffentliche Verbreitung**:  
   Die Software darf nicht verkauft, unterlizenziert oder öffentlich weiterverbreitet werden, ohne vorherige schriftliche Genehmigung von CyberSpaceConsulting.
   
2. **Zentrale Verwaltung**:  
   Alle offiziellen Versionen und Updates werden ausschließlich über das ursprüngliche Repository verwaltet.

3. **Attribution erforderlich**:  
   Jede Nutzung oder Bereitstellung der Software muss die Herkunft des Projekts klar angeben:  
   "CyberSpaceConsulting – Original source available at the official repository."

4. **Kommerzielle Nutzung erlaubt (mit Einschränkungen)**:  
   Die Software darf in kommerziellen Kontexten verwendet werden, jedoch nicht als eigenständiges Produkt oder Dienstleistung weiterverkauft werden.

5. **Keine Garantie**:  
   Die Software wird "wie besehen" bereitgestellt, ohne jegliche Garantien oder Gewährleistungen.

6. **Verbotene Nutzung in KI-Training**:  
   Die Software darf nicht für das Training oder Fine-Tuning von KI-Modellen verwendet werden, ohne ausdrückliche Genehmigung.

Für weitere Informationen oder Genehmigungen, kontaktiere:  
📧 license@cyberspaceconsulting.de

---

### Feedback und Beiträge

Beiträge und Verbesserungsvorschläge sind willkommen! Erstellen Sie einfach ein Issue oder einen Pull Request.

---

### Autor

Erstellt von [The1AndOni](https://github.com/The1AndOni).
