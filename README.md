# Mailcow Backup Script V2

Ein Bash-Skript zur Sicherung von Mailcow-Daten mit Unterstützung für WebDAV- und FTP-Uploads. Dieses Projekt ermöglicht es, automatisierte Backups zu erstellen, zu verschlüsseln und auf Remote-Server hochzuladen.

## Ordnerstruktur

```
Mailcow-BackupV2/
├── mailcow-backup.sh
├── setup.sh
├── Dependencies/
│   ├── Dependencies/dependencies.txt
│   └── Dependencies/install_dependencies.sh
├── Configs/
│   └── (verschlüsselte Konfigurationsdateien)
└── Upload/  
     ├── Upload/FTP-Upload.sh  
     └── Upload/WebDAV-Upload.sh
```

## Features

- **Automatisierte Backups**: Erstellt Backups von Mailcow-Daten.
- **Verschlüsselung**: Konfigurationsdateien werden mit GPG verschlüsselt.
- **Remote-Upload**: Unterstützt WebDAV und FTP für das Hochladen von Backups.
- **Cronjob-Integration**: Automatische Planung von Backups und Uploads.
- **Retention Management**: Löscht alte Backups lokal und remote basierend auf definierten Aufbewahrungszeiten.

## Voraussetzungen

- Betriebssystem: Linux
- Abhängigkeiten:
  - `gpg`
  - `curl`
  - `cron`
  - `tar`

## Installation

1. **Download Repository**:

   Sie können das Repository mithilfe von GitClone einfach runterladen.

   ```bash
   git clone https://github.com/the1andoni/mailcow-backupV2.git 
   ```
   
   Anschließend wechseln Sie in das neue Verzeichnis und machen die Scripte mithilfe folgendes Befehles ausführbar.

   ```bash
   chmod +x Mailcow-BackupV2/**/*.sh
   ```

2. **Abhängigkeiten installieren**:

   Sie können die Abhängigkeiten entweder manuell oder mit dem bereitgestellten Skript installieren:

   ```bash
   sudo xargs -a Dependencies/dependencies.txt apt install -y
   ```

   **Oder**:

   ```bash
   sudo ./Dependencies/install_dependencies.sh
   ```

3. **Setup ausführen**:

   Starten Sie das Setup-Skript, um die Konfigurationen zu erstellen und Cronjobs einzurichten:

   ```bash
   sudo ./setup.sh
   ```

   Folgen Sie den Anweisungen im Skript, um die Backup-Methoden (WebDAV/FTP) und Aufbewahrungszeiten zu konfigurieren.

## Nutzung

- **Backup manuell starten**:

  ```bash
  sudo ./mailcow-backup.sh
  ```

- **WebDAV-Upload manuell starten**:

  ```bash
  sudo ./Upload/WebDAV-Upload.sh
  ```

- **FTP-Upload manuell starten**:

  ```bash
  sudo ./Upload/FTP-Upload.sh
  ```

## Konfiguration

Die Konfigurationsdateien werden während des Setups erstellt und verschlüsselt im Ordner `Configs` gespeichert. Sie enthalten sensible Informationen wie Zugangsdaten und sollten niemals unverschlüsselt gespeichert werden.

## Hinweis zum `.Configs`-Ordner

Der Ordner `.Configs` wird verwendet, um sensible Konfigurationsdateien zu speichern, die für den Betrieb des Skripts erforderlich sind. 

- Eine leere Datei namens `.gitkeep` wurde hinzugefügt, um sicherzustellen, dass der Ordner in Git enthalten ist.
- Bitte füge deine eigenen Konfigurationsdateien in diesen Ordner ein, nachdem du das Repository geklont hast. (Wird sonst automatisch vom `setup.sh`-Skript erstellt)
- Achte darauf, dass sensible Daten wie Zugangsdaten sicher gespeichert werden und nicht versehentlich in das Repository hochgeladen werden.

Falls der Ordner `.Configs` fehlt, wird er automatisch vom `setup.sh`-Skript erstellt.

## Automatisierung

Das Setup-Skript richtet automatisch Cronjobs ein, um Backups und Uploads regelmäßig auszuführen. Sie können die Cronjobs mit dem Befehl `crontab -l` überprüfen.

## Sicherheit

- Die Konfigurationsdateien werden mit GPG verschlüsselt, um sensible Daten zu schützen.
- Für FTP-Uploads kann ein Zertifikat-Fingerabdruck angegeben werden, um die Verbindung abzusichern.

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz.

---

### Feedback und Beiträge

Beiträge und Verbesserungsvorschläge sind willkommen! Erstellen Sie einfach ein Issue oder einen Pull Request.

---

### Autor

Erstellt von [The1AndOni](https://github.com/The1AndOni).
