#!/bin/bash

# Überprüfen, ob das Skript mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript mit sudo aus."
  exit 1
fi

# Konfigurationsdatei entschlüsseln und laden
echo "Bitte geben Sie das GPG-Passwort ein:"
read -s -p "Passwort: " gpg_password
echo
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/mailcow-config.sh.gpg")

# Variablen
BACKUP_DIR="/backup/mailcow"
MAILCOW_DIR="/opt/mailcow-dockerized"
DATE=$(date +"%Y-%m-%d")
BACKUP_PATH="$BACKUP_DIR/mailcow-$DATE"
TAR_FILE="$BACKUP_DIR/mailcow-backup-$DATE.tar.gz"

# Sicherstellen, dass das Backup-Verzeichnis existiert
sudo mkdir -p "$BACKUP_DIR"
sudo mkdir -p "$BACKUP_PATH"

echo "[+] Starte Mailcow-Backup..."

# Mailcow-Backup starten und Pfad direkt übergeben
cd "$MAILCOW_DIR" || { echo "❌ Fehler: Mailcow-Verzeichnis nicht gefunden!"; exit 1; }
echo "$BACKUP_PATH" | ./helper-scripts/backup_and_restore.sh backup all --delete-days 7

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

# Optional: Alte Backups löschen (z. B. älter als 7 Tage)
echo "[+] Lösche Backups, die älter als 7 Tage sind..."
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -exec rm -f {} \;
echo "[✅] Alte Backups erfolgreich gelöscht."