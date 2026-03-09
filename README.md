# mailcow Backup Script V2

[🇬🇧 English](#english) | [🇩🇪 Deutsch](#deutsch)

---

<a name="english"></a>
## 🇬🇧 English

A Bash script for backing up mailcow data with support for WebDAV, FTP/SFTP, NAS, and S3 uploads. This project enables automated backups, encryption, and remote server uploads.

### 📁 Folder Structure

```
mailcow-backup/
├── mailcow-backup.sh
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
     └── WebDAV-Upload.sh
```

### ✨ Features

- **Automated Backups**: Creates backups of mailcow data
- **Encryption**: Configuration files are encrypted with GPG (AES256)
- **Flexible Upload Options**: Supports WebDAV, FTP/SFTP, NAS (LAN), and S3-compatible storage
- **Automatic Dependency Check**: Setup and upload scripts verify required tools and offer installation
- **Two-Phase Self-Update**: Update script updates itself first, then the rest of the repository
- **Systemd Timer Integration**: Automatic scheduling of backups and uploads
- **Retention Management**: Deletes old backups locally and remotely based on defined retention periods
- **Service Repair**: Automatically repairs systemd service paths after updates

### 📋 Prerequisites

- **Operating System**: Linux (Debian/Ubuntu recommended)
- **Basic Dependencies** (for all features):
  - `gpg` - GPG encryption
  - `tar` - Archiving
  - `systemd` - Timer management

- **Upload-specific Dependencies**:
  - **WebDAV/FTP/SFTP**: `curl`
  - **S3**: `awscli` (AWS CLI)
  - **NAS**: `mountpoint` (usually pre-installed)

**Note**: The setup script automatically checks for missing dependencies and offers installation.

### 🌿 Branch Information

**You are on the `V2-LEGACY` branch - the legacy version 2.x support track.**

This branch is maintained for users who need to stay on version 2.x. For new installations, we recommend using version 3.x.

| Branch | Purpose | Recommended For |
|--------|---------|----------------|
| `V2-LEGACY` | **Legacy v2.x (this branch)** | ⚠️ Existing v2 installations only |
| `V3` | Stable v3.x release | ✅ **New installations** |
| `main` | Active development | ⚠️ Development/testing only |

**Clone instructions:**
```bash
# Legacy v2 version (this branch)
git clone -b V2-LEGACY https://github.com/the1andoni/mailcow-backup.git

# Recommended: Stable v3 version
git clone -b V3 https://github.com/the1andoni/mailcow-backup.git
```

**Migration to V3:** If you want to upgrade from V2 to V3, please check the [V3 release notes](https://github.com/the1andoni/mailcow-backup/releases/tag/v3.0.0) for breaking changes and migration instructions.

### 🚀 Installation

   Sie können das Repository mithilfe von Git Clone einfach runterladen.

   ```bash
   git clone -b V2-LEGACY https://github.com/the1andoni/mailcow-backup.git 
   ```
   
   Scripts will automatically be made executable during setup.

   Alternatively, a Debian package is available for download:

   ```bash
   chmod +x mailcow-backup/**/*.sh
   ```

2. **Install Dependencies** (optional):

   You can install dependencies in advance or let the setup script check and install them automatically:

   ```bash
   sudo ./Dependencies/install_dependencies.sh
   ```

   Or manually:

   ```bash
   sudo xargs -a Dependencies/dependencies.txt apt install -y
   ```

3. **Run Setup**:

   Start the setup script to create configurations and set up systemd timers:

   ```bash
   sudo ./setup.sh
   ```

   **The setup script performs the following steps**:
   - Automatically checks for available updates
   - Verifies required dependencies for selected upload methods
   - Offers installation of missing tools
   - Configures selected backup methods (WebDAV/FTP/SFTP/NAS/S3)
   - Sets up systemd timers for automated backups

### 🌿 Branch Strategy

This repository uses multiple branches for different stability levels:

| Branch | Purpose | Stability | For Production Use |
|--------|---------|-----------|-------------------|
| `main` | Active development, new features | ⚠️ May be unstable | ❌ No |
| `V3` | Stable release track (v3.x) | ✅ Stable | ✅ **Yes** |
| `V2-LEGACY` | Legacy support (v2.x) | ✅ Stable | ⚠️ Legacy only |

**For production systems, always use the `V3` branch or tagged releases (`v3.0.0`, `v3.1.0`, etc.).**

**Clone instructions:**
```bash
# Stable production version (recommended)
git clone -b V3 https://github.com/the1andoni/mailcow-backup.git

# Development version (may be unstable)
git clone https://github.com/the1andoni/mailcow-backup.git
# or explicitly:
git clone -b main https://github.com/the1andoni/mailcow-backup.git

# Legacy v2 version
git clone -b V2-LEGACY https://github.com/the1andoni/mailcow-backup.git
```

**Development workflow:**
- New features → `main` branch
- Stable releases → pushed to `V3` after testing
- Critical bugfixes → `V3` or `V2-LEGACY` directly

### 🔐 Automated Backups & GPG Password

For scheduled backups and uploads to work without interaction, the GPG password is automatically saved during setup in a file (`/root/.mailcow-gpg-pass`).

**Warning:** The file is only readable by root and is created by the setup script as follows:

```bash
echo "YOUR_GPG_PASSWORD" | sudo tee /root/.mailcow-gpg-pass > /dev/null
sudo chmod 600 /root/.mailcow-gpg-pass
```

The backup script automatically reads this password and decrypts the configuration.  
**Note:** Only change the password in this file if you also re-encrypt the configuration!

### 🎯 Usage

- **Install Updates**:

  ```bash
  sudo ./update.sh
  ```

  The update script:
  - Shows changes in update.sh first (Phase 1)
  - Updates itself and restarts if needed
  - Shows all changes in the repository (Phase 2)
  - Asks for confirmation before applying updates
  - Makes all scripts executable
  - Repairs systemd services automatically

- **Manual Backup**:

  ```bash
  sudo ./Backup/mailcow-backup.sh
  ```

- **Manual WebDAV Upload**:

  ```bash
  sudo ./Upload/WebDAV-Upload.sh
  ```

- **Manual FTP/SFTP Upload**:

  ```bash
  sudo ./Upload/FTP-Upload.sh
  ```

- **Manual NAS Upload**:

  ```bash
  sudo ./Upload/NAS-Upload.sh
  ```

- **Manual S3 Upload**:

  ```bash
  sudo ./Upload/S3-Upload.sh
  ```

- **Manage Systemd Timers**:
  - **Check status**:
    ```bash
    systemctl status mailcow-backup.timer
    systemctl status mailcow-webdav-upload.timer
    systemctl status mailcow-ftp-upload.timer
    systemctl status mailcow-nas-upload.timer
    systemctl status mailcow-s3-upload.timer
    ```
  - **Start manually**:
    ```bash
    systemctl start mailcow-backup.service
    ```
  - **Disable**:
    ```bash
    systemctl disable mailcow-backup.timer
    ```

### ⚙️ Configuration

Configuration files are created during setup and stored encrypted in the `Configs` folder. They contain sensitive information such as credentials and should never be stored unencrypted.

### 📤 Upload Methods Explained

#### WebDAV
- HTTPS-based upload
- Compatible with Nextcloud, ownCloud, HiDrive, etc.
- **Requires**: `curl`, `gpg`

#### FTP/SFTP
- **FTP**: Optional with TLS and certificate fingerprint pinning
- **SFTP**: Secure SSH-based transfer
- **Requires**: `curl`, `gpg`

#### NAS (Network Storage)
- Local or LAN-based NAS
- Expects mounted directory (e.g., via SMB/CIFS or NFS)
- **Requires**: `mountpoint`, `gpg`
- **Setup**: Mount your NAS before running the script

#### S3 (Cloud Storage)
- AWS S3 and S3-compatible services (Wasabi, MinIO, Backblaze B2)
- Lifecycle rules for automatic retention recommended
- **Requires**: `awscli`, `gpg`
- **Note**: Remote retention should be configured via bucket lifecycle rules

### 🔒 Security

- **Encryption**: All configuration files are encrypted with GPG (AES256)
- **Password Management**: GPG password is securely stored in `/root/.mailcow-gpg-pass` (only readable by root)
- **FTP-TLS**: Optional certificate pinning for secure FTP connections
- **SFTP**: Uses SSH authentication via `curl`
- **Dependency Checks**: All scripts verify required tools before execution
- **Status Flags**: Upload scripts check for backup completion before uploading

### 🔄 Backup Workflow

1. **Backup Script** (`mailcow-backup.sh`) runs:
   - Creates timestamped `.tar.gz` archive
   - Sets completion flag: `/tmp/mailcow-backup.status`
   - Deletes old local backups based on retention

2. **Upload Scripts** check for completion:
   - Verify `/tmp/mailcow-backup.status` exists
   - Upload latest backup
   - Delete old remote backups based on retention

### 📜 License

This project is licensed under the **CyberSpaceConsulting Public License v1.0**.  
Full license terms can be found in the [LICENSE](LICENSE) file.

#### Key License Points:
1. **No Resale or Public Distribution**: Software may not be sold, sublicensed, or publicly distributed without prior written permission
2. **Central Management**: All official versions and updates are managed exclusively through the original repository
3. **Attribution Required**: "CyberSpaceConsulting – Original source available at the official repository"
4. **Commercial Use Allowed (with Restrictions)**: May be used in commercial contexts but not resold as standalone product
5. **No Warranty**: Software is provided "as is" without any warranties

---

<a name="deutsch"></a>
## 🇩🇪 Deutsch

Ein Bash-Skript zur Sicherung von mailcow-Daten mit Unterstützung für WebDAV-, FTP/SFTP-, NAS- und S3-Uploads. Dieses Projekt ermöglicht es, automatisierte Backups zu erstellen, zu verschlüsseln und auf Remote-Server hochzuladen.

### 📁 Ordnerstruktur

```
mailcow-backup/
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

### ✨ Features

- **Automatisierte Backups**: Erstellt Backups von mailcow-Daten
- **Verschlüsselung**: Konfigurationsdateien werden mit GPG (AES256) verschlüsselt
- **Flexible Upload-Optionen**: Unterstützt WebDAV, FTP/SFTP, NAS (LAN) und S3-kompatible Speicher
- **Automatische Dependency-Prüfung**: Setup und Upload-Skripte überprüfen benötigte Tools und bieten Installation an
- **Zweiphasen Self-Update**: Update-Script aktualisiert sich zuerst selbst, dann das Repository
- **Systemd-Timer-Integration**: Automatische Planung von Backups und Uploads
- **Retention Management**: Löscht alte Backups lokal und remote basierend auf definierten Aufbewahrungszeiten
- **Service-Reparatur**: Repariert automatisch systemd-Service-Pfade nach Updates

### 📋 Voraussetzungen

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

### 🌿 Branch-Information

**Sie befinden sich auf dem `V2-LEGACY`-Branch - dem Legacy-Support-Track für Version 2.x.**

Dieser Branch wird für Benutzer gepflegt, die bei Version 2.x bleiben müssen. Für neue Installationen empfehlen wir Version 3.x.

| Branch | Zweck | Empfohlen für |
|--------|-------|---------------|
| `V2-LEGACY` | **Legacy v2.x (dieser Branch)** | ⚠️ Nur bestehende v2-Installationen |
| `V3` | Stabile v3.x Version | ✅ **Neue Installationen** |
| `main` | Aktive Entwicklung | ⚠️ Nur Entwicklung/Tests |

**Clone-Anweisungen:**
```bash
# Legacy v2 Version (dieser Branch)
git clone -b V2-LEGACY https://github.com/the1andoni/mailcow-backup.git

# Empfohlen: Stabile v3 Version
git clone -b V3 https://github.com/the1andoni/mailcow-backup.git
```

**Migration zu V3:** Falls Sie von V2 auf V3 upgraden möchten, prüfen Sie bitte die [V3 Release Notes](https://github.com/the1andoni/mailcow-backup/releases/tag/v3.0.0) für Breaking Changes und Migrationsanleitung.

### 🚀 Installation

1. **Repository herunterladen**:

   ```bash
   git clone -b V2-LEGACY https://github.com/the1andoni/mailcow-backup.git
   cd mailcow-backup
   ```
   
   Die Scripte werden automatisch beim Setup ausführbar gemacht.

   Alternativ steht ein Debian Paket zum Download zur Verfügung:

   ```bash
   wget https://github.com/the1andoni/mailcow-backup/releases/download/v3.0.0/mailcow-backup_3.0.0_all.deb
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

### 🌿 Branch-Strategie

Dieses Repository verwendet mehrere Branches für unterschiedliche Stabilitätsstufen:

| Branch | Zweck | Stabilität | Für Produktiv-Einsatz |
|--------|-------|------------|----------------------|
| `main` | Aktive Entwicklung, neue Features | ⚠️ Kann instabil sein | ❌ Nein |
| `V3` | Stabiler Release-Track (v3.x) | ✅ Stabil | ✅ **Ja** |
| `V2-LEGACY` | Legacy-Support (v2.x) | ✅ Stabil | ⚠️ Nur Legacy |

**Für Produktivsysteme sollte immer der `V3`-Branch oder getaggte Releases (`v3.0.0`, `v3.1.0`, etc.) verwendet werden.**

**Clone-Anweisungen:**
```bash
# Stabile Produktivversion (empfohlen)
git clone -b V3 https://github.com/the1andoni/mailcow-backup.git

# Entwicklungsversion (kann instabil sein)
git clone https://github.com/the1andoni/mailcow-backup.git
# oder explizit:
git clone -b main https://github.com/the1andoni/mailcow-backup.git

# Legacy v2 Version
git clone -b V2-LEGACY https://github.com/the1andoni/mailcow-backup.git
```

**Entwicklungs-Workflow:**
- Neue Features → `main` Branch
- Stabile Releases → nach Tests auf `V3` gepusht
- Kritische Bugfixes → direkt in `V3` oder `V2-LEGACY`

### 🔐 Automatisierte Backups & GPG-Passwort

Damit geplante Backups und Uploads ohne Interaktion funktionieren, wird das GPG-Passwort während des Setups automatisch in einer Datei (`/root/.mailcow-gpg-pass`) gespeichert.

**Achtung:** Die Datei ist nur für root lesbar und wird vom Setup-Skript wie folgt angelegt:

```bash
echo "DEIN_GPG_PASSWORT" | sudo tee /root/.mailcow-gpg-pass > /dev/null
sudo chmod 600 /root/.mailcow-gpg-pass
```

Das Backup-Skript liest dieses Passwort automatisch ein und entschlüsselt damit die Konfiguration.  
**Hinweis:** Ändere das Passwort in dieser Datei nur, wenn du auch die Konfiguration neu verschlüsselst!

### 🎯 Nutzung

- **Updates installieren**:

  ```bash
  sudo ./update.sh
  ```

  Das Update-Skript:
  - Zeigt zuerst Änderungen in update.sh (Phase 1)
  - Aktualisiert sich selbst und startet neu falls nötig
  - Zeigt alle Änderungen im Repository (Phase 2)
  - Fragt vor Anwendung der Updates nach Bestätigung
  - Macht alle Scripts ausführbar
  - Repariert systemd-Services automatisch

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

- **Systemd-Timer verwalten**:
  - **Status überprüfen**:
    ```bash
    systemctl status mailcow-backup.timer
    systemctl status mailcow-webdav-upload.timer
    systemctl status mailcow-ftp-upload.timer
    systemctl status mailcow-nas-upload.timer
    systemctl status mailcow-s3-upload.timer
    ```
  - **Manuell starten**:
    ```bash
    systemctl start mailcow-backup.service
    ```
  - **Deaktivieren**:
    ```bash
    systemctl disable mailcow-backup.timer
    ```

### ⚙️ Konfiguration

Die Konfigurationsdateien werden während des Setups erstellt und verschlüsselt im Ordner `Configs` gespeichert. Sie enthalten sensible Informationen wie Zugangsdaten und sollten niemals unverschlüsselt gespeichert werden.

### 📤 Upload-Methoden im Detail

#### WebDAV
- HTTPS-basierter Upload
- Kompatibel mit Nextcloud, ownCloud, HiDrive, etc.
- **Benötigt**: `curl`, `gpg`

#### FTP/SFTP
- **FTP**: Optional mit TLS und Zertifikat-Fingerabdruck
- **SFTP**: Sichere SSH-basierte Übertragung
- **Benötigt**: `curl`, `gpg`

#### NAS (Network Storage)
- Lokales oder LAN-basiertes NAS
- Erwartet eingehängtes Verzeichnis (z. B. via SMB/CIFS oder NFS)
- **Benötigt**: `mountpoint`, `gpg`
- **Setup**: Hänge dein NAS ein, bevor du das Script ausführst

#### S3 (Cloud Storage)
- AWS S3 und S3-kompatible Dienste (Wasabi, MinIO, Backblaze B2)
- Lifecycle-Regeln für automatische Retention empfohlen
- **Benötigt**: `awscli`, `gpg`
- **Hinweis**: Remote-Retention sollte über Bucket-Lifecycle-Regeln konfiguriert werden

### 🔒 Sicherheit

- **Verschlüsselung**: Alle Konfigurationsdateien werden mit GPG (AES256) verschlüsselt
- **Passwort-Verwaltung**: Das GPG-Passwort wird sicher in `/root/.mailcow-gpg-pass` abgelegt (nur für root lesbar)
- **FTP-TLS**: Optional mit Zertifikat-Pinning für sichere FTP-Verbindungen
- **SFTP**: Nutzt SSH-Authentifizierung über `curl`
- **Dependency-Checks**: Alle Skripte prüfen benötigte Tools vor Ausführung
- **Status-Flags**: Upload-Scripts prüfen Backup-Abschluss vor dem Upload

### 🔄 Backup-Workflow

1. **Backup-Script** (`mailcow-backup.sh`) läuft:
   - Erstellt `.tar.gz` Archiv mit Zeitstempel
   - Setzt Completion-Flag: `/tmp/mailcow-backup.status`
   - Löscht alte lokale Backups basierend auf Retention

2. **Upload-Scripts** prüfen auf Abschluss:
   - Verifizieren dass `/tmp/mailcow-backup.status` existiert
   - Laden neuestes Backup hoch
   - Löschen alte Remote-Backups basierend auf Retention

### 📜 Lizenz

Dieses Projekt steht unter der **CyberSpaceConsulting Public License v1.0**.  
Die vollständigen Lizenzbedingungen findest du in der [LICENSE](LICENSE)-Datei.

#### Wichtige Punkte der Lizenz:
1. **Keine Weiterveräußerung oder öffentliche Verbreitung**: Die Software darf nicht verkauft, unterlizenziert oder öffentlich weiterverbreitet werden ohne vorherige schriftliche Genehmigung
2. **Zentrale Verwaltung**: Alle offiziellen Versionen und Updates werden ausschließlich über das ursprüngliche Repository verwaltet
3. **Attribution erforderlich**: "CyberSpaceConsulting – Original source available at the official repository"
4. **Kommerzielle Nutzung erlaubt (mit Einschränkungen)**: Die Software darf in kommerziellen Kontexten verwendet werden, jedoch nicht als eigenständiges Produkt weiterverkauft werden
5. **Keine Garantie**: Die Software wird "wie besehen" bereitgestellt, ohne jegliche Garantien

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
