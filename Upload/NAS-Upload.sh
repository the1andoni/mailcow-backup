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

# Check required dependencies
for cmd in gpg mountpoint; do
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

if [ ! -f "$CONFIG_DIR/nas-config.sh.gpg" ]; then
  echo "Error: NAS configuration $CONFIG_DIR/nas-config.sh.gpg not found!"
  exit 1
fi

gpg_password=$(cat "$GPG_PASS_FILE")
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/nas-config.sh.gpg")

BACKUP_DIR="/backup/mailcow"
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)
if [ -z "$LATEST_BACKUP" ] || [ ! -f "$LATEST_BACKUP" ]; then
  echo "Error: No backup found!"
  exit 1
fi

NAS_MOUNT_PATH="${NAS_MOUNT_PATH:-/mnt/mailcow-backup}"
NAS_UPLOAD_DIR="${NAS_UPLOAD_DIR:-/}"
if [[ "$NAS_UPLOAD_DIR" != /* ]]; then
  NAS_UPLOAD_DIR="/$NAS_UPLOAD_DIR"
fi

if [ ! -d "$NAS_MOUNT_PATH" ]; then
  echo "Error: NAS mount path $NAS_MOUNT_PATH does not exist!"
  exit 1
fi

if ! mountpoint -q "$NAS_MOUNT_PATH"; then
  echo "Error: $NAS_MOUNT_PATH is not mounted."
  exit 1
fi

TARGET_DIR="$NAS_MOUNT_PATH$NAS_UPLOAD_DIR"
mkdir -p "$TARGET_DIR"

BACKUP_NAME=$(basename "$LATEST_BACKUP")
cp "$LATEST_BACKUP" "$TARGET_DIR/$BACKUP_NAME"

if [ $? -ne 0 ]; then
  echo "Error: Upload to NAS failed!"
  exit 1
fi

echo "Backup successfully saved to NAS: $TARGET_DIR/$BACKUP_NAME"

if [ -n "$REMOTE_RETENTION" ]; then
  echo "Deleting NAS backups older than $REMOTE_RETENTION days..."
  find "$TARGET_DIR" -maxdepth 1 -type f -name "*.tar.gz" -mtime +"$REMOTE_RETENTION" -exec rm -f {} \;
fi

if [ -n "$LOCAL_RETENTION" ]; then
  echo "Deleting local backups older than $LOCAL_RETENTION days..."
  find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;
fi

echo "NAS upload completed."
