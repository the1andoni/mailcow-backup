#!/bin/bash

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

# Ensure backup is completed
if [ ! -f /tmp/mailcow-backup.status ]; then
  echo "❌ Error: Backup not yet completed!"
  exit 1
fi

# Check required dependencies
for cmd in gpg curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Error: Dependency '$cmd' is missing."
    echo "Please run 'sudo ./Dependencies/install_dependencies.sh'."
    exit 1
  fi
done

# Decrypt and load configuration file
CONFIG_DIR="$(dirname "$0")/../Configs"
GPG_PASS_FILE="/root/.mailcow-gpg-pass"
if [ ! -f "$GPG_PASS_FILE" ]; then
  echo "❌ Error: GPG password file $GPG_PASS_FILE not found!"
  exit 1
fi
gpg_password=$(cat "$GPG_PASS_FILE")
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/webdav-config.sh.gpg")

# Variables
BACKUP_DIR="/backup/mailcow"
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz | head -n 1)

# Check if backup exists
if [ ! -f "$LATEST_BACKUP" ]; then
  echo "❌ Error: No backup found!"
  exit 1
fi

# Upload backup to WebDAV
echo "[+] Uploading backup to WebDAV server..."
UPLOAD_RESPONSE=$(curl -u "$WEBDAV_USER:$WEBDAV_PASSWORD" -T "$LATEST_BACKUP" "$WEBDAV_URL" --silent --write-out "%{http_code}")

# Check if upload was successful
if [ "$UPLOAD_RESPONSE" -eq 201 ] || [ "$UPLOAD_RESPONSE" -eq 204 ]; then
  echo "[✅] Backup successfully uploaded to WebDAV server!"
else
  echo "❌ Error: Upload failed (HTTP code: $UPLOAD_RESPONSE)"
  exit 1
fi

# Delete old local backups
if [ -n "$LOCAL_RETENTION" ]; then
  echo "[+] Deleting local backups older than $LOCAL_RETENTION days..."
  find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;
  echo "[✅] Old local backups successfully deleted."
else
  echo "[⚠️] No retention interval defined for local backups. No old backups will be deleted."
fi