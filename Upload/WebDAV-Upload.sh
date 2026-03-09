#!/bin/bash

# Überprüfen, ob das Skript mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript mit sudo aus."
  exit 1
fi

# Sicherstellen, dass das Backup abgeschlossen ist
if [ ! -f /tmp/mailcow-backup.status ]; then
  echo "❌ Fehler: Backup ist noch nicht abgeschlossen!"
  exit 1
fi

# Benötigte Abhängigkeiten prüfen
for cmd in gpg curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Fehler: Abhängigkeit '$cmd' fehlt."
    echo "Bitte führen Sie 'sudo ./Dependencies/install_dependencies.sh' aus."
    exit 1
  fi
done

# Konfigurationsdatei entschlüsseln und laden
CONFIG_DIR="$(dirname "$0")/../Configs"
GPG_PASS_FILE="/root/.mailcow-gpg-pass"
if [ ! -f "$GPG_PASS_FILE" ]; then
  echo "❌ Fehler: GPG-Passwortdatei $GPG_PASS_FILE nicht gefunden!"
  exit 1
fi
gpg_password=$(cat "$GPG_PASS_FILE")
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/webdav-config.sh.gpg")

# Variablen
BACKUP_DIR="/backup/mailcow"
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz | head -n 1)

# Prüfen, ob ein Backup vorhanden ist
if [ ! -f "$LATEST_BACKUP" ]; then
  echo "❌ Fehler: Kein Backup gefunden!"
  exit 1
fi

# Backup auf WebDAV hochladen
echo "[+] Lade Backup auf WebDAV-Server hoch..."
UPLOAD_RESPONSE=$(curl -u "$WEBDAV_USER:$WEBDAV_PASSWORD" -T "$LATEST_BACKUP" "$WEBDAV_URL" --silent --write-out "%{http_code}")

# Prüfen, ob der Upload erfolgreich war
if [ "$UPLOAD_RESPONSE" -eq 201 ] || [ "$UPLOAD_RESPONSE" -eq 204 ]; then
  echo "[✅] Backup erfolgreich auf WebDAV-Server hochgeladen!"
else
  echo "❌ Fehler: Upload fehlgeschlagen (HTTP-Code: $UPLOAD_RESPONSE)"
  exit 1
fi

# Alte Backups lokal löschen
if [ -n "$LOCAL_RETENTION" ]; then
  echo "[+] Lösche lokale Backups, die älter als $LOCAL_RETENTION Tage sind..."
  find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;
  echo "[✅] Alte lokale Backups erfolgreich gelöscht."
else
  echo "[⚠️] Kein Löschintervall für lokale Backups definiert. Es werden keine alten Backups gelöscht."
fi