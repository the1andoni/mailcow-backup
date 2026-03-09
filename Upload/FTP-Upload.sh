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
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/ftp-config.sh.gpg")

# Compatible defaults for existing configurations
FTP_PROTOCOL="${FTP_PROTOCOL:-ftp}"
FTP_UPLOAD_DIR="${FTP_UPLOAD_DIR:-/}"

FTP_PROTOCOL=$(echo "$FTP_PROTOCOL" | tr '[:upper:]' '[:lower:]')
if [ "$FTP_PROTOCOL" != "ftp" ] && [ "$FTP_PROTOCOL" != "sftp" ]; then
  echo "❌ Error: Invalid protocol '$FTP_PROTOCOL'. Allowed: ftp, sftp"
  exit 1
fi

if [[ "$FTP_UPLOAD_DIR" != /* ]]; then
  FTP_UPLOAD_DIR="/$FTP_UPLOAD_DIR"
fi

# Variables
BACKUP_DIR="/backup/mailcow"
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz | head -n 1)
BACKUP_BASENAME=$(basename "$LATEST_BACKUP")
TARGET_URL="$FTP_PROTOCOL://$FTP_SERVER$FTP_UPLOAD_DIR/$BACKUP_BASENAME"

# Check if backup exists
if [ ! -f "$LATEST_BACKUP" ]; then
  echo "❌ Error: No backup found!"
  exit 1
fi

# Upload backup via FTP or SFTP
if [ "$FTP_PROTOCOL" = "ftp" ] && [ -n "$FTP_CERTIFICATE_FINGERPRINT" ]; then
  echo "[+] Uploading backup via FTP with TLS..."
  curl --pinnedpubkey "$FTP_CERTIFICATE_FINGERPRINT" -u "$FTP_USER:$FTP_PASSWORD" -T "$LATEST_BACKUP" "$TARGET_URL"
else
  echo "[+] Uploading backup via $FTP_PROTOCOL..."
  curl -u "$FTP_USER:$FTP_PASSWORD" -T "$LATEST_BACKUP" "$TARGET_URL"
fi

# Check if upload was successful
if [ $? -eq 0 ]; then
  echo "[✅] Backup successfully uploaded via $FTP_PROTOCOL!"
else
  echo "❌ Error: Upload via $FTP_PROTOCOL failed!"
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