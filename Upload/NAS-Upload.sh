#!/bin/bash

# Überprüfen, ob das Skript mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript mit sudo aus."
  exit 1
fi

# Sicherstellen, dass das Backup abgeschlossen ist
if [ ! -f /tmp/mailcow-backup.status ]; then
  echo "Fehler: Backup ist noch nicht abgeschlossen!"
  exit 1
fi

# Benötigte Abhängigkeiten prüfen
for cmd in gpg mountpoint; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Fehler: Abhängigkeit '$cmd' fehlt."
    echo "Bitte führen Sie 'sudo ./Dependencies/install_dependencies.sh' aus."
    exit 1
  fi
done

CONFIG_DIR="$(dirname "$0")/../Configs"
GPG_PASS_FILE="/root/.mailcow-gpg-pass"
if [ ! -f "$GPG_PASS_FILE" ]; then
  echo "Fehler: GPG-Passwortdatei $GPG_PASS_FILE nicht gefunden!"
  exit 1
fi

if [ ! -f "$CONFIG_DIR/nas-config.sh.gpg" ]; then
  echo "Fehler: NAS-Konfiguration $CONFIG_DIR/nas-config.sh.gpg nicht gefunden!"
  exit 1
fi

gpg_password=$(cat "$GPG_PASS_FILE")
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/nas-config.sh.gpg")

BACKUP_DIR="/backup/mailcow"
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)
if [ -z "$LATEST_BACKUP" ] || [ ! -f "$LATEST_BACKUP" ]; then
  echo "Fehler: Kein Backup gefunden!"
  exit 1
fi

NAS_MOUNT_PATH="${NAS_MOUNT_PATH:-/mnt/mailcow-backup}"
NAS_UPLOAD_DIR="${NAS_UPLOAD_DIR:-/}"
if [[ "$NAS_UPLOAD_DIR" != /* ]]; then
  NAS_UPLOAD_DIR="/$NAS_UPLOAD_DIR"
fi

if [ ! -d "$NAS_MOUNT_PATH" ]; then
  echo "Fehler: NAS-Mount-Pfad $NAS_MOUNT_PATH existiert nicht!"
  exit 1
fi

if ! mountpoint -q "$NAS_MOUNT_PATH"; then
  echo "Fehler: $NAS_MOUNT_PATH ist nicht eingehängt."
  exit 1
fi

TARGET_DIR="$NAS_MOUNT_PATH$NAS_UPLOAD_DIR"
mkdir -p "$TARGET_DIR"

BACKUP_NAME=$(basename "$LATEST_BACKUP")
cp "$LATEST_BACKUP" "$TARGET_DIR/$BACKUP_NAME"

if [ $? -ne 0 ]; then
  echo "Fehler: Upload auf NAS fehlgeschlagen!"
  exit 1
fi

echo "Backup erfolgreich auf NAS gespeichert: $TARGET_DIR/$BACKUP_NAME"

if [ -n "$REMOTE_RETENTION" ]; then
  echo "lösche NAS-Backups, die älter als $REMOTE_RETENTION Tage sind..."
  find "$TARGET_DIR" -maxdepth 1 -type f -name "*.tar.gz" -mtime +"$REMOTE_RETENTION" -exec rm -f {} \;
fi

if [ -n "$LOCAL_RETENTION" ]; then
  echo "lösche lokale Backups, die älter als $LOCAL_RETENTION Tage sind..."
  find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;
fi

echo "NAS-Upload abgeschlossen."
