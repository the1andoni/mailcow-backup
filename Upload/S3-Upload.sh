#!/bin/bash

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

# Ensure backup is completed
if [ ! -f /tmp/mailcow-backup.status ]; then
  echo "Error: Backup not yet completed!"
  exit 1
fi

for cmd in gpg aws; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Dependency '$cmd' is missing."
    echo "Please run 'sudo ./Dependencies/install_dependencies.sh'."
    exit 1
  fi
done

CONFIG_DIR="$(dirname "$0")/../Configs"
GPG_PASS_FILE="/root/.mailcow-gpg-pass"
if [ ! -f "$GPG_PASS_FILE" ]; then
  echo "Error: GPG password file $GPG_PASS_FILE not found!"
  exit 1
fi

if [ ! -f "$CONFIG_DIR/s3-config.sh.gpg" ]; then
  echo "Error: S3 configuration $CONFIG_DIR/s3-config.sh.gpg not found!"
  exit 1
fi

gpg_password=$(cat "$GPG_PASS_FILE")
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/s3-config.sh.gpg")

if [ -z "$S3_BUCKET" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_DEFAULT_REGION" ]; then
  echo "Error: Incomplete S3 configuration."
  exit 1
fi

BACKUP_DIR="/backup/mailcow"
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)
if [ -z "$LATEST_BACKUP" ] || [ ! -f "$LATEST_BACKUP" ]; then
  echo "Error: No backup found!"
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
  echo "Error: Upload to S3 failed!"
  exit 1
fi

echo "Backup successfully uploaded to S3: $S3_TARGET"

if [ -n "$LOCAL_RETENTION" ]; then
  echo "Deleting local backups older than $LOCAL_RETENTION days..."
  find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;
fi

echo "Note: Remote retention for S3 should be configured via bucket lifecycle rules."
echo "S3 upload completed."
