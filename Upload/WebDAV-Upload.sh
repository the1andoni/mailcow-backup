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
BACKUP_BASENAME=$(basename "$LATEST_BACKUP")

# Check if backup exists
if [ ! -f "$LATEST_BACKUP" ]; then
  echo "❌ Error: No backup found!"
  exit 1
fi

# Ensure WebDAV URL ends with /
if [[ "$WEBDAV_URL" != */ ]]; then
  WEBDAV_URL="$WEBDAV_URL/"
fi

# Upload backup to WebDAV
echo "[+] Uploading backup to WebDAV server..."
HTTP_CODE=$(curl -u "$WEBDAV_USER:$WEBDAV_PASSWORD" -T "$LATEST_BACKUP" "${WEBDAV_URL}${BACKUP_BASENAME}" -w "%{http_code}" -o /dev/null --silent)

# Check if upload was successful (201 Created or 204 No Content)
if [ "$HTTP_CODE" -eq 201 ] || [ "$HTTP_CODE" -eq 204 ]; then
  echo "[✅] Backup successfully uploaded to WebDAV server!"
else
  echo "❌ Error: Upload failed (HTTP code: $HTTP_CODE)"
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
