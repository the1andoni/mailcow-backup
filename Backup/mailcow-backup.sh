#!/bin/bash

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

# Check required dependencies
for cmd in gpg tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Error: Dependency '$cmd' is missing."
    echo "Please run 'sudo ./Dependencies/install_dependencies.sh'."
    exit 1
  fi
done

# Path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../Configs"
GPG_PASS_FILE="/root/.mailcow-gpg-pass"

# Check if GPG password file exists
if [ ! -f "$GPG_PASS_FILE" ]; then
  echo "❌ Error: GPG password file $GPG_PASS_FILE not found!"
  exit 1
fi

gpg_password=$(cat "$GPG_PASS_FILE")
LOCAL_RETENTION=""

# Load retention settings from any available config
for config in "$CONFIG_DIR"/ftp-config.sh.gpg "$CONFIG_DIR"/webdav-config.sh.gpg "$CONFIG_DIR"/nas-config.sh.gpg "$CONFIG_DIR"/s3-config.sh.gpg; do
  if [ -f "$config" ]; then
    source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$config" 2>/dev/null | grep "^LOCAL_RETENTION=")
    if [ -n "$LOCAL_RETENTION" ]; then
      break
    fi
  fi
done

# Variables
BACKUP_DIR="/backup/mailcow"
MAILCOW_DIR="/opt/mailcow-dockerized"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/mailcow-backup_$TIMESTAMP.tar.gz"

# Remove old status file
rm -f /tmp/mailcow-backup.status

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Check if mailcow directory exists
if [ ! -d "$MAILCOW_DIR" ]; then
  echo "❌ Error: Mailcow directory $MAILCOW_DIR not found!"
  exit 1
fi

echo "[+] Creating mailcow backup..."
echo "[+] Backup location: $BACKUP_FILE"

# Create tar.gz backup of mailcow directory
tar -czf "$BACKUP_FILE" -C "$(dirname "$MAILCOW_DIR")" "$(basename "$MAILCOW_DIR")" 2>/dev/null

if [ $? -eq 0 ]; then
  echo "[✅] Backup successfully created!"
  echo "[+] Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
  
  # Create status file to signal upload scripts
  touch /tmp/mailcow-backup.status
  
  # Delete old local backups if retention is set
  if [ -n "$LOCAL_RETENTION" ]; then
    echo "[+] Deleting local backups older than $LOCAL_RETENTION days..."
    find "$BACKUP_DIR" -type f -name "mailcow-backup_*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;
  fi
else
  echo "❌ Error: Backup creation failed!"
  exit 1
fi

echo "[✅] Backup process completed."