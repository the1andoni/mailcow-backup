#!/bin/bash

# Überprüfen, ob das Skript mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript mit sudo aus."
  exit 1
fi

# Konfigurationsdatei entschlüsseln und laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../Configs"
GPG_PASS_FILE="/root/.mailcow-gpg-pass"
if [ ! -f "$GPG_PASS_FILE" ]; then
  echo "❌ Fehler: GPG-Passwortdatei $GPG_PASS_FILE nicht gefunden!"
  exit 1
fi
gpg_password=$(cat "$GPG_PASS_FILE")

# Beziehe Retention aus einer vorhandenen Upload-Konfiguration (FTP oder WebDAV)
if [ -f "$CONFIG_DIR/ftp-config.sh.gpg" ]; then
  source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/ftp-config.sh.gpg")
elif [ -f "$CONFIG_DIR/webdav-config.sh.gpg" ]; then
  source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/webdav-config.sh.gpg")
else
  echo "❌ Fehler: Keine Konfiguration gefunden (ftp-config.sh.gpg oder webdav-config.sh.gpg)."
  exit 1
fi

# Variablen
BACKUP_DIR="/backup/mailcow"
MAILCOW_DIR="/opt/mailcow-dockerized"
DATE=$(date +"%Y-%m-%d")
BACKUP_PATH="$BACKUP_DIR/mailcow-$DATE"
TAR_FILE="$BACKUP_DIR/mailcow-backup-$DATE.tar.gz"

# Sicherstellen, dass das Backup-Verzeichnis existiert
sudo mkdir -p "$BACKUP_DIR"
sudo mkdir -p "$BACKUP_PATH"

echo "[+] Starte mailcow-Backup..."

# mailcow-Backup starten und Pfad direkt übergeben
cd "$MAILCOW_DIR" || { echo "❌ Fehler: mailcow-Verzeichnis nicht gefunden!"; exit 1; }
DELETE_DAYS="${LOCAL_RETENTION:-7}"
echo "$BACKUP_PATH" | ./helper-scripts/backup_and_restore.sh backup all --delete-days "$DELETE_DAYS"

# Prüfen, ob das Backup erstellt wurde
if [ ! -d "$BACKUP_PATH" ] || [ -z "$(ls -A "$BACKUP_PATH")" ]; then
    echo "❌ Fehler: Backup-Ordner ist leer oder wurde nicht erstellt!"
    exit 1
fi

echo "[+] Backup erfolgreich erstellt: $BACKUP_PATH"

# Backup in ein tar.gz-Archiv packen
tar -czvf "$TAR_FILE" -C "$BACKUP_DIR" "mailcow-$DATE"

# Prüfen, ob das Archiv existiert
if [ ! -f "$TAR_FILE" ]; then
    echo "❌ Fehler: Backup-Archiv wurde nicht erstellt!"
    exit 1
fi

echo "[+] Archiv erfolgreich erstellt: $TAR_FILE"

# Optional: Alte Backups löschen basierend auf LOCAL_RETENTION
if [ -n "$LOCAL_RETENTION" ]; then
  echo "[+] Lösche Backups, die älter als $LOCAL_RETENTION Tage sind..."
  find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;
  echo "[✅] Alte Backups erfolgreich gelöscht."
else
  echo "[⚠️] Kein Löschintervall definiert. Es werden keine alten Backups gelöscht."
fi

# Backup erfolgreich abgeschlossen
echo "Backup abgeschlossen." > /tmp/mailcow-backup.status