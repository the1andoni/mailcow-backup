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
MAILCOW_HELPER_SCRIPT="$MAILCOW_DIR/helper-scripts/backup_and_restore.sh"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/mailcow-$TIMESTAMP"
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

# Check if mailcow helper backup script exists
if [ ! -x "$MAILCOW_HELPER_SCRIPT" ]; then
  echo "❌ Error: Mailcow helper script $MAILCOW_HELPER_SCRIPT not found or not executable!"
  exit 1
fi

echo "[+] Creating mailcow backup..."
echo "[+] Raw backup path: $BACKUP_PATH"
echo "[+] Archive path: $BACKUP_FILE"

# Run mailcow's own backup helper first (same flow as official helper usage)
mkdir -p "$BACKUP_PATH"
if ! (
  cd "$MAILCOW_DIR" &&
  echo "$BACKUP_PATH" | ./helper-scripts/backup_and_restore.sh backup all --delete-days 7
); then
  echo "❌ Error: mailcow backup helper failed!"
  rm -rf "$BACKUP_PATH"
  exit 1
fi

# Ensure helper created non-empty backup data
if [ ! -d "$BACKUP_PATH" ] || [ -z "$(ls -A "$BACKUP_PATH" 2>/dev/null)" ]; then
  echo "❌ Error: Backup directory is empty or was not created: $BACKUP_PATH"
  rm -rf "$BACKUP_PATH"
  exit 1
fi

# Archive helper output to keep upload compatibility (.tar.gz expected by upload scripts)
if ! tar -czf "$BACKUP_FILE" -C "$BACKUP_DIR" "$(basename "$BACKUP_PATH")" 2>/dev/null; then
  echo "❌ Error: Failed to create compressed backup archive!"
  rm -rf "$BACKUP_PATH"
  exit 1
fi

# Ensure archive exists before cleanup and status flag
if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ Error: Backup archive was not created!"
  rm -rf "$BACKUP_PATH"
  exit 1
fi

# Remove uncompressed helper backup directory after archive creation
rm -rf "$BACKUP_PATH"

echo "[✅] Backup successfully created!"
echo "[+] Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Create status file to signal upload scripts
touch /tmp/mailcow-backup.status

# Delete old local backups if retention is set
if [ -n "$LOCAL_RETENTION" ]; then
  echo "[+] Deleting local backups older than $LOCAL_RETENTION days..."
  find "$BACKUP_DIR" -type f -name "mailcow-backup_*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;
fi

echo "[✅] Backup process completed."