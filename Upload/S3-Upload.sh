#!/bin/bash

# Ueberpruefen, ob das Skript mit sudo ausgefuehrt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte fuehren Sie dieses Skript mit sudo aus."
  exit 1
fi

# Sicherstellen, dass das Backup abgeschlossen ist
if [ ! -f /tmp/mailcow-backup.status ]; then
  echo "Fehler: Backup ist noch nicht abgeschlossen!"
  exit 1
fi

for cmd in gpg aws; do
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

if [ ! -f "$CONFIG_DIR/s3-config.sh.gpg" ]; then
  echo "Fehler: S3-Konfiguration $CONFIG_DIR/s3-config.sh.gpg nicht gefunden!"
  exit 1
fi

gpg_password=$(cat "$GPG_PASS_FILE")
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/s3-config.sh.gpg")

if [ -z "$S3_BUCKET" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_DEFAULT_REGION" ]; then
  echo "Fehler: Unvollstaendige S3-Konfiguration."
  exit 1
fi

BACKUP_DIR="/backup/mailcow"
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)
if [ -z "$LATEST_BACKUP" ] || [ ! -f "$LATEST_BACKUP" ]; then
  echo "Fehler: Kein Backup gefunden!"
  exit 1
fi

BACKUP_NAME=$(basename "$LATEST_BACKUP")
S3_PREFIX="${S3_PREFIX#/}"
if [ -n "$S3_PREFIX" ]; then
  S3_TARGET="s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_NAME"
else
  S3_TARGET="s3://$S3_BUCKET/$BACKUP_NAME"
fi

AWS_CMD=(aws s3 cp "$LATEST_BACKUP" "$S3_TARGET")
if [ -n "$S3_ENDPOINT" ]; then
  AWS_CMD+=(--endpoint-url "$S3_ENDPOINT")
fi

"${AWS_CMD[@]}"
if [ $? -ne 0 ]; then
  echo "Fehler: Upload nach S3 fehlgeschlagen!"
  exit 1
fi

echo "Backup erfolgreich nach S3 hochgeladen: $S3_TARGET"

if [ -n "$LOCAL_RETENTION" ]; then
  echo "Loesche lokale Backups, die aelter als $LOCAL_RETENTION Tage sind..."
  find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;
fi

echo "Hinweis: Remote-Retention fuer S3 sollte ueber Bucket-Lifecycle-Regeln konfiguriert werden."
echo "S3-Upload abgeschlossen."
