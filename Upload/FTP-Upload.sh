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
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/ftp-config.sh.gpg")

# Kompatible Defaults fuer bestehende Konfigurationen
FTP_PROTOCOL="${FTP_PROTOCOL:-ftp}"
FTP_UPLOAD_DIR="${FTP_UPLOAD_DIR:-/}"

FTP_PROTOCOL=$(echo "$FTP_PROTOCOL" | tr '[:upper:]' '[:lower:]')
if [ "$FTP_PROTOCOL" != "ftp" ] && [ "$FTP_PROTOCOL" != "sftp" ]; then
  echo "❌ Fehler: Ungueltiges Protokoll '$FTP_PROTOCOL'. Erlaubt sind: ftp, sftp"
  exit 1
fi

if [[ "$FTP_UPLOAD_DIR" != /* ]]; then
  FTP_UPLOAD_DIR="/$FTP_UPLOAD_DIR"
fi

# Variablen
BACKUP_DIR="/backup/mailcow"
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz | head -n 1)
BACKUP_BASENAME=$(basename "$LATEST_BACKUP")
TARGET_URL="$FTP_PROTOCOL://$FTP_SERVER$FTP_UPLOAD_DIR/$BACKUP_BASENAME"

# Prüfen, ob ein Backup vorhanden ist
if [ ! -f "$LATEST_BACKUP" ]; then
  echo "❌ Fehler: Kein Backup gefunden!"
  exit 1
fi

# Backup per FTP oder SFTP hochladen
if [ "$FTP_PROTOCOL" = "ftp" ] && [ -n "$FTP_CERTIFICATE_FINGERPRINT" ]; then
  echo "[+] Lade Backup per FTP mit TLS hoch..."
  curl --pinnedpubkey "$FTP_CERTIFICATE_FINGERPRINT" -u "$FTP_USER:$FTP_PASSWORD" -T "$LATEST_BACKUP" "$TARGET_URL"
else
  echo "[+] Lade Backup per $FTP_PROTOCOL hoch..."
  curl -u "$FTP_USER:$FTP_PASSWORD" -T "$LATEST_BACKUP" "$TARGET_URL"
fi

# Prüfen, ob der Upload erfolgreich war
if [ $? -eq 0 ]; then
  echo "[✅] Backup erfolgreich per $FTP_PROTOCOL hochgeladen!"
else
  echo "❌ Fehler: Upload per $FTP_PROTOCOL fehlgeschlagen!"
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