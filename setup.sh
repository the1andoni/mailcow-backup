#!/bin/bash

show_usage() {
  echo "Usage: $0 [--status|--status-detailed]"
  echo "  --status           Prüft mailcow systemd-Timer und Services kurz"
  echo "  --status-detailed  zusätzlich letzter Lauf / Timerzeitpunkte / zuletzt Logeinträge"
}

# Action mode from command line
STATUS_MODE=""
if [ "$1" = "--status" ] || [ "$1" = "--status-detailed" ]; then
  STATUS_MODE="$1"
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_usage
  exit 0
fi

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

# Path to repository directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

get_configured_uploads() {
  local active=""
  [ -f "$CONFIG_DIR/ftp-config.sh.gpg" ] && active="${active}FTP "
  [ -f "$CONFIG_DIR/webdav-config.sh.gpg" ] && active="${active}WebDAV "
  [ -f "$CONFIG_DIR/nas-config.sh.gpg" ] && active="${active}NAS "
  [ -f "$CONFIG_DIR/s3-config.sh.gpg" ] && active="${active}S3 "
  echo "${active:-none}"
}

get_timer_times() {
  local unit="$1"
  local line
  line=$(systemctl list-timers --all --no-legend | grep -E "^${unit}\.timer" | head -n 1)
  if [ -z "$line" ]; then
    echo "next=n/a left=n/a last=n/a"
  else
    echo "$line" | awk '{printf "next=%s left=%s last=%s", $1, $2, $3}'
  fi
}

check_mailcow_unit_status() {
  local mode="$1"
  local units=("mailcow-backup" "mailcow-ftp-upload" "mailcow-webdav-upload" "mailcow-nas-upload" "mailcow-s3-upload")
  local unit timer_state timer_enabled service_state scheduler

  echo "\nÜberprüfe mailcow systemd Units..."
  echo "Konfigurierte Uploads: $(get_configured_uploads)"

  for unit in "${units[@]}"; do
    if systemctl list-unit-files --all | grep -q "^${unit}\.timer"; then
      timer_state=$(systemctl is-active "${unit}.timer" 2>/dev/null || echo "inactive")
      timer_enabled=$(systemctl is-enabled "${unit}.timer" 2>/dev/null || echo "disabled")
      service_state=$(systemctl is-active "${unit}.service" 2>/dev/null || echo "inactive")
      echo "[$unit] timer: ${timer_state} (enabled: ${timer_enabled}), service: ${service_state}"
      if [ "$mode" = "--status-detailed" ]; then
        scheduler=$(get_timer_times "$unit")
        echo "        ${scheduler}"
        echo "        Journal (letzte 5 Zeilen):"
        journalctl -u "${unit}.service" -n 5 --no-pager 2>/dev/null | sed 's/^/        /'
      fi
    elif systemctl list-unit-files --all | grep -q "^${unit}\.service"; then
      service_state=$(systemctl is-active "${unit}.service" 2>/dev/null || echo "inactive")
      echo "[$unit] timer: not configured, service: ${service_state}"
    else
      echo "[$unit] nicht konfiguriert (keine Timer/Service-Unit gefunden)."
    fi
  done
}

if [ -n "$STATUS_MODE" ]; then
  check_mailcow_unit_status "$STATUS_MODE"
  exit 0
fi

# Check for available updates
echo "Checking for available updates..."
if [ -d .git ]; then
  git fetch origin main &>/dev/null
  
  LOCAL=$(git rev-parse HEAD)
  REMOTE=$(git rev-parse origin/main)
  
  if [ "$LOCAL" != "$REMOTE" ]; then
    echo ""
    echo "⚠️  An update is available!"
    echo "It is recommended to update the repository first."
    echo ""
    read -p "Do you want to update now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "Performing update..."
      SETUP_STASH_NAME="setup-stash-$(date +%s)"
      SETUP_STASH_CREATED=false
      if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        if git stash push --include-untracked -m "$SETUP_STASH_NAME" &>/dev/null; then
          SETUP_STASH_CREATED=true
        else
          echo "Error: Could not save local changes."
          exit 1
        fi
      fi

      git pull origin main &>/dev/null
      if [ $? -eq 0 ]; then
        echo "✓ Update successfully completed."
        # Restore stash changes (if any)
        if [ "$SETUP_STASH_CREATED" = true ]; then
          git stash pop &>/dev/null
        fi
        # Reload script
        echo "Restarting setup..."
        exec "$0" "$@"
      else
        echo "Error during update. Aborting."
        if [ "$SETUP_STASH_CREATED" = true ]; then
          git stash pop &>/dev/null
        fi
        exit 1
      fi
    fi
  fi
else
  echo "No Git repository found. Skipping update check."
fi

CONFIG_DIR="$(cd "$(dirname "$0")" && pwd)/Configs"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/Backup/mailcow-backup.sh"
FTP_UPLOAD_SCRIPT="$SCRIPT_DIR/Upload/FTP-Upload.sh"
WEBDAV_UPLOAD_SCRIPT="$SCRIPT_DIR/Upload/WebDAV-Upload.sh"
NAS_UPLOAD_SCRIPT="$SCRIPT_DIR/Upload/NAS-Upload.sh"
S3_UPLOAD_SCRIPT="$SCRIPT_DIR/Upload/S3-Upload.sh"
mkdir -p "$CONFIG_DIR"

echo "\Info: Du kannst setup.sh mit --status, --status-detailed oder --help aufrufen."

ensure_dependencies() {
  local feature="$1"
  shift
  local missing=()
  local cmd

  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -eq 0 ]; then
    return 0
  fi

  echo "Missing dependencies for $feature: ${missing[*]}"
  read -p "Do you want to try installing missing dependencies now? (y/n) " install_choice
  if [ "$install_choice" = "y" ]; then
    if [ -f "$REPO_DIR/Dependencies/install_dependencies.sh" ]; then
      sudo bash "$REPO_DIR/Dependencies/install_dependencies.sh"
    else
      echo "Error: install_dependencies.sh not found."
      return 1
    fi
  else
    return 1
  fi

  missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: These dependencies are still missing: ${missing[*]}"
    echo "Please install them manually and restart setup.sh."
    return 1
  fi

  return 0
}

echo "Welcome to the setup script!"

# Ask for encryption password
echo "Please enter a password for encrypting the configuration files:"
read -s -p "GPG Password: " gpg_password
echo
export GPG_TTY=$(tty) # For GPG agent compatibility

# Initialize GPG agent
echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output /dev/null <<< "Test"

# Save GPG password securely in /root/.mailcow-gpg-pass
echo "$gpg_password" | sudo tee /root/.mailcow-gpg-pass > /dev/null
sudo chmod 600 /root/.mailcow-gpg-pass
echo "GPG password securely saved in /root/.mailcow-gpg-pass."

# Check if existing configurations should be overwritten
if [ -f "$CONFIG_DIR/ftp-config.sh.gpg" ] || [ -f "$CONFIG_DIR/webdav-config.sh.gpg" ] || [ -f "$CONFIG_DIR/nas-config.sh.gpg" ] || [ -f "$CONFIG_DIR/s3-config.sh.gpg" ]; then
  echo "Configuration files already exist. Do you want to overwrite them? (y/n)"
  read -p "Input: " overwrite
  if [ "$overwrite" != "y" ]; then
    echo "Setup cancelled."
    exit 0
  fi
fi

# Ask for backup retention time
echo "How many days should backups be retained locally?"
read -p "Local (in days): " local_retention
echo "How many days should backups be retained on the remote server (WebDAV/FTP)?"
read -p "Remote (in days): " remote_retention

# Configure backup methods
echo ""
echo "═══════════════════════════════════════════════════"
echo "Choose upload methods to configure:"
echo "═══════════════════════════════════════════════════"
echo "1) WebDAV"
echo "2) FTP / SFTP"
echo "3) NAS Upload"
echo "4) S3 Upload"
echo ""
echo "Select multiple options (e.g. 1,2,4 or enter for all):"
read -p "Your choice: " upload_methods

# Default to all if empty
if [ -z "$upload_methods" ]; then
  upload_methods="1,2,3,4"
fi

# Process WebDAV
if [[ "$upload_methods" =~ 1 ]]; then
  ensure_dependencies "WebDAV" gpg curl || exit 1
  echo ""
  echo "━ WebDAV Configuration"
  echo "Please enter the WebDAV URL (e.g. https://webdav-server/path/):"
  read -p "WebDAV URL: " webdav_url
  echo "Please enter your WebDAV username:"
  read -p "Username: " webdav_user
  echo "Please enter your WebDAV password:"
  read -s -p "Password: " webdav_password
  echo

  rm -f "$CONFIG_DIR/webdav-config.sh"
  echo "WEBDAV_URL=\"$webdav_url\"" > "$CONFIG_DIR/webdav-config.sh"
  echo "WEBDAV_USER=\"$webdav_user\"" >> "$CONFIG_DIR/webdav-config.sh"
  echo "WEBDAV_PASSWORD=\"$webdav_password\"" >> "$CONFIG_DIR/webdav-config.sh"
  echo "LOCAL_RETENTION=\"$local_retention\"" >> "$CONFIG_DIR/webdav-config.sh"
  echo "REMOTE_RETENTION=\"$remote_retention\"" >> "$CONFIG_DIR/webdav-config.sh"

  echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$CONFIG_DIR/webdav-config.sh.gpg" "$CONFIG_DIR/webdav-config.sh"
  rm -f "$CONFIG_DIR/webdav-config.sh"
  echo "✓ WebDAV configuration saved."
fi

# Process FTP/SFTP
if [[ "$upload_methods" =~ 2 ]]; then
  ensure_dependencies "FTP/SFTP" gpg curl || exit 1
  echo ""
  echo "━ FTP/SFTP Configuration"
  echo "Which protocol do you want to use?"
  echo "1) FTP"
  echo "2) SFTP"
  read -p "Please select (1 or 2): " ftp_protocol_option

  case "$ftp_protocol_option" in
    2)
      ftp_protocol="sftp"
      ;;
    *)
      ftp_protocol="ftp"
      ;;
  esac

  echo "Please enter the server address (without protocol, e.g. backup.example.com):"
  read -p "Server: " ftp_server
  echo "Please enter the upload target path (e.g. /mailcow-backups):"
  read -p "Upload path: " ftp_upload_dir
  echo "Please enter your username:"
  read -p "Username: " ftp_user
  echo "Please enter your password:"
  read -s -p "Password: " ftp_password
  echo

  ftp_certificate_fingerprint=""
  if [ "$ftp_protocol" = "ftp" ]; then
    echo "Optional: Please enter the FTP certificate fingerprint (or leave empty):"
    read -p "Certificate fingerprint: " ftp_certificate_fingerprint
  fi
  echo

  rm -f "$CONFIG_DIR/ftp-config.sh"
  echo "FTP_PROTOCOL=\"$ftp_protocol\"" > "$CONFIG_DIR/ftp-config.sh"
  echo "FTP_SERVER=\"$ftp_server\"" >> "$CONFIG_DIR/ftp-config.sh"
  echo "FTP_UPLOAD_DIR=\"$ftp_upload_dir\"" >> "$CONFIG_DIR/ftp-config.sh"
  echo "FTP_USER=\"$ftp_user\"" >> "$CONFIG_DIR/ftp-config.sh"
  echo "FTP_PASSWORD=\"$ftp_password\"" >> "$CONFIG_DIR/ftp-config.sh"
  echo "FTP_CERTIFICATE_FINGERPRINT=\"$ftp_certificate_fingerprint\"" >> "$CONFIG_DIR/ftp-config.sh"
  echo "LOCAL_RETENTION=\"$local_retention\"" >> "$CONFIG_DIR/ftp-config.sh"
  echo "REMOTE_RETENTION=\"$remote_retention\"" >> "$CONFIG_DIR/ftp-config.sh"

  echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$CONFIG_DIR/ftp-config.sh.gpg" "$CONFIG_DIR/ftp-config.sh"
  rm -f "$CONFIG_DIR/ftp-config.sh"
  echo "✓ FTP/SFTP configuration saved."
fi

# Process NAS
if [[ "$upload_methods" =~ 3 ]]; then
  ensure_dependencies "NAS" gpg mountpoint || exit 1
  echo ""
  echo "━ NAS Configuration"
  echo "Please enter the local NAS mount path (e.g. /mnt/backup-nas):"
  read -p "NAS mount path: " nas_mount_path
  echo "Please enter the target folder on the NAS (e.g. /mailcow):"
  read -p "NAS target folder: " nas_upload_dir
  echo

  rm -f "$CONFIG_DIR/nas-config.sh"
  echo "NAS_MOUNT_PATH=\"$nas_mount_path\"" > "$CONFIG_DIR/nas-config.sh"
  echo "NAS_UPLOAD_DIR=\"$nas_upload_dir\"" >> "$CONFIG_DIR/nas-config.sh"
  echo "LOCAL_RETENTION=\"$local_retention\"" >> "$CONFIG_DIR/nas-config.sh"
  echo "REMOTE_RETENTION=\"$remote_retention\"" >> "$CONFIG_DIR/nas-config.sh"

  echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$CONFIG_DIR/nas-config.sh.gpg" "$CONFIG_DIR/nas-config.sh"
  rm -f "$CONFIG_DIR/nas-config.sh"
  echo "✓ NAS configuration saved."
fi

# Process S3
if [[ "$upload_methods" =~ 4 ]]; then
  ensure_dependencies "S3" gpg aws || exit 1
  echo ""
  echo "━ S3 Configuration"
  echo "Please enter the S3 bucket name (e.g. my-backup-bucket):"
  read -p "S3 bucket: " s3_bucket
  echo "Optional: S3 prefix in bucket (e.g. mailcow, leave empty for root):"
  read -p "S3 prefix: " s3_prefix
  echo "Optional: S3 endpoint for S3-compatible services (e.g. https://s3.eu-central-1.amazonaws.com):"
  read -p "S3 endpoint: " s3_endpoint
  echo "Please enter the AWS Access Key ID:"
  read -p "Access Key ID: " aws_access_key_id
  echo "Please enter the AWS Secret Access Key:"
  read -s -p "Secret Access Key: " aws_secret_access_key
  echo
  echo "Please enter the AWS region (e.g. eu-central-1):"
  read -p "Region: " aws_region
  echo

  rm -f "$CONFIG_DIR/s3-config.sh"
  echo "S3_BUCKET=\"$s3_bucket\"" > "$CONFIG_DIR/s3-config.sh"
  echo "S3_PREFIX=\"$s3_prefix\"" >> "$CONFIG_DIR/s3-config.sh"
  echo "S3_ENDPOINT=\"$s3_endpoint\"" >> "$CONFIG_DIR/s3-config.sh"
  echo "AWS_ACCESS_KEY_ID=\"$aws_access_key_id\"" >> "$CONFIG_DIR/s3-config.sh"
  echo "AWS_SECRET_ACCESS_KEY=\"$aws_secret_access_key\"" >> "$CONFIG_DIR/s3-config.sh"
  echo "AWS_DEFAULT_REGION=\"$aws_region\"" >> "$CONFIG_DIR/s3-config.sh"
  echo "LOCAL_RETENTION=\"$local_retention\"" >> "$CONFIG_DIR/s3-config.sh"
  echo "REMOTE_RETENTION=\"$remote_retention\"" >> "$CONFIG_DIR/s3-config.sh"

  echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$CONFIG_DIR/s3-config.sh.gpg" "$CONFIG_DIR/s3-config.sh"
  rm -f "$CONFIG_DIR/s3-config.sh"
  echo "✓ S3 configuration saved."
fi

# Set up systemd timer for backup
echo "How often should the backup be performed?"
echo "1) Daily"
echo "2) Weekly"
echo "3) Monthly"
read -p "Please select an option (1, 2 or 3): " frequency

case $frequency in
  1)
    echo "Please enter the time for the daily backup (e.g. 02:00):"
    read -p "Backup time: " backup_time
    schedule="*-*-* ${backup_time}:00"
    ;;
  2)
    echo "Please enter the day of week and time for the weekly backup (e.g. Sun 02:00):"
    read -p "Backup time: " backup_time
    schedule="${backup_time}:00"
    ;;
  3)
    echo "Please enter the day of month and time for the monthly backup (e.g. 1 02:00):"
    read -p "Backup time: " backup_time
    schedule="*-*-${backup_time}:00"
    ;;
  *)
    echo "Invalid selection. Backup will be performed daily at 02:00 by default."
    schedule="*-*-* 02:00:00"
    ;;
esac

cat <<EOF | sudo tee /etc/systemd/system/mailcow-backup.service
[Unit]
Description=Mailcow Backup Script

[Service]
Type=oneshot
ExecStart=/bin/bash $BACKUP_SCRIPT
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/mailcow-backup.timer
[Unit]
Description=Run Mailcow Backup

[Timer]
OnCalendar=$schedule
Persistent=true
Unit=mailcow-backup.service

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now mailcow-backup.timer

# Set up systemd timer for FTP upload
echo "Do you want to set up automatic FTP upload? (y/n)"
read -p "Input: " ftp_upload_choice
if [ "$ftp_upload_choice" == "y" ]; then
    echo "How often should the FTP upload be performed?"
    echo "1) Daily"
    echo "2) Weekly"
    echo "3) Monthly"
    read -p "Please select an option (1, 2 or 3): " ftp_frequency

    case $ftp_frequency in
      1)
        echo "Please enter the time for the daily FTP upload (e.g. 03:00):"
        read -p "FTP upload time: " ftp_upload_time
        ftp_schedule="*-*-* ${ftp_upload_time}:00"
        ;;
      2)
        echo "Please enter the day of week and time for the weekly FTP upload (e.g. Sun 03:00):"
        read -p "FTP upload time: " ftp_upload_time
        ftp_schedule="${ftp_upload_time}:00"
        ;;
      3)
        echo "Please enter the day of month and time for the monthly FTP upload (e.g. 1 03:00):"
        read -p "FTP upload time: " ftp_upload_time
        ftp_schedule="*-*-${ftp_upload_time}:00"
        ;;
      *)
        echo "Invalid selection. FTP upload will be performed daily at 03:00 by default."
        ftp_schedule="*-*-* 03:00:00"
        ;;
    esac

    cat <<EOF | sudo tee /etc/systemd/system/mailcow-ftp-upload.service
[Unit]
Description=Mailcow FTP Upload Script

[Service]
Type=oneshot
ExecStart=/bin/bash $FTP_UPLOAD_SCRIPT
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    cat <<EOF | sudo tee /etc/systemd/system/mailcow-ftp-upload.timer
[Unit]
Description=Run Mailcow FTP Upload

[Timer]
OnCalendar=$ftp_schedule
Persistent=true
Unit=mailcow-ftp-upload.service

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now mailcow-ftp-upload.timer
fi

# Set up systemd timer for WebDAV upload
echo "Do you want to set up automatic WebDAV upload? (y/n)"
read -r webdav_upload
if [[ "$webdav_upload" =~ ^[Yy]$ ]]; then
  echo "How often should the WebDAV upload be performed?"
  echo "1) Daily"
  echo "2) Weekly"
  echo "3) Monthly"
  read -p "Please select an option (1, 2 or 3): " webdav_frequency

  case $webdav_frequency in
    1)
      echo "Please enter the time for the daily WebDAV upload (e.g. 04:00):"
      read -p "WebDAV upload time: " webdav_upload_time
      webdav_schedule="*-*-* ${webdav_upload_time}:00"
      ;;
    2)
      echo "Please enter the day of week and time for the weekly WebDAV upload (e.g. Sun 04:00):"
      read -p "WebDAV upload time: " webdav_upload_time
      webdav_schedule="${webdav_upload_time}:00"
      ;;
    3)
      echo "Please enter the day of month and time for the monthly WebDAV upload (e.g. 1 04:00):"
      read -p "WebDAV upload time: " webdav_upload_time
      webdav_schedule="*-*-${webdav_upload_time}:00"
      ;;
    *)
      echo "Invalid selection. WebDAV upload will be performed daily at 04:00 by default."
      webdav_schedule="*-*-* 04:00:00"
      ;;
  esac

  cat <<EOF | sudo tee /etc/systemd/system/mailcow-webdav-upload.service
[Unit]
Description=Mailcow WebDAV Upload Script

[Service]
Type=oneshot
ExecStart=/bin/bash $WEBDAV_UPLOAD_SCRIPT
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

  cat <<EOF | sudo tee /etc/systemd/system/mailcow-webdav-upload.timer
[Unit]
Description=Run Mailcow WebDAV Upload

[Timer]
OnCalendar=$webdav_schedule
Persistent=true
Unit=mailcow-webdav-upload.service

[Install]
WantedBy=timers.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now mailcow-webdav-upload.timer
fi

# Set up systemd timer for NAS upload
if [ -f "$CONFIG_DIR/nas-config.sh.gpg" ]; then
echo "Do you want to set up automatic NAS upload? (y/n)"
read -p "Input: " nas_upload_choice
if [ "$nas_upload_choice" == "y" ]; then
    echo "How often should the NAS upload be performed?"
    echo "1) Daily"
    echo "2) Weekly"
    echo "3) Monthly"
    read -p "Please select an option (1, 2 or 3): " nas_frequency

    case $nas_frequency in
      1)
        echo "Please enter the time for the daily NAS upload (e.g. 05:00):"
        read -p "NAS upload time: " nas_upload_time
        nas_schedule="*-*-* ${nas_upload_time}:00"
        ;;
      2)
        echo "Please enter the day of week and time for the weekly NAS upload (e.g. Sun 05:00):"
        read -p "NAS upload time: " nas_upload_time
        nas_schedule="${nas_upload_time}:00"
        ;;
      3)
        echo "Please enter the day of month and time for the monthly NAS upload (e.g. 1 05:00):"
        read -p "NAS upload time: " nas_upload_time
        nas_schedule="*-*-${nas_upload_time}:00"
        ;;
      *)
        echo "Invalid selection. NAS upload will be performed daily at 05:00 by default."
        nas_schedule="*-*-* 05:00:00"
        ;;
    esac

    cat <<EOF | sudo tee /etc/systemd/system/mailcow-nas-upload.service
[Unit]
Description=Mailcow NAS Upload Script

[Service]
Type=oneshot
ExecStart=/bin/bash $NAS_UPLOAD_SCRIPT
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    cat <<EOF | sudo tee /etc/systemd/system/mailcow-nas-upload.timer
[Unit]
Description=Run Mailcow NAS Upload

[Timer]
OnCalendar=$nas_schedule
Persistent=true
Unit=mailcow-nas-upload.service

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now mailcow-nas-upload.timer
fi
  fi

# Set up systemd timer for S3 upload
  if [ -f "$CONFIG_DIR/s3-config.sh.gpg" ]; then
  echo "Do you want to set up automatic S3 upload? (y/n)"
  read -p "Input: " s3_upload_choice
  if [ "$s3_upload_choice" == "y" ]; then
    echo "How often should the S3 upload be performed?"
    echo "1) Daily"
    echo "2) Weekly"
    echo "3) Monthly"
    read -p "Please select an option (1, 2 or 3): " s3_frequency

    case $s3_frequency in
      1)
        echo "Please enter the time for the daily S3 upload (e.g. 06:00):"
        read -p "S3 upload time: " s3_upload_time
        s3_schedule="*-*-* ${s3_upload_time}:00"
        ;;
      2)
        echo "Please enter the day of week and time for the weekly S3 upload (e.g. Sun 06:00):"
        read -p "S3 upload time: " s3_upload_time
        s3_schedule="${s3_upload_time}:00"
        ;;
      3)
        echo "Please enter the day of month and time for the monthly S3 upload (e.g. 1 06:00):"
        read -p "S3 upload time: " s3_upload_time
        s3_schedule="*-*-${s3_upload_time}:00"
        ;;
      *)
        echo "Invalid selection. S3 upload will be performed daily at 06:00 by default."
        s3_schedule="*-*-* 06:00:00"
        ;;
    esac

    cat <<EOF | sudo tee /etc/systemd/system/mailcow-s3-upload.service
[Unit]
Description=Mailcow S3 Upload Script

[Service]
Type=oneshot
ExecStart=/bin/bash $S3_UPLOAD_SCRIPT
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    cat <<EOF | sudo tee /etc/systemd/system/mailcow-s3-upload.timer
[Unit]
Description=Run Mailcow S3 Upload

[Timer]
OnCalendar=$s3_schedule
Persistent=true
Unit=mailcow-s3-upload.service

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now mailcow-s3-upload.timer
fi
  fi

echo "Setup completed! The systemd timers have been successfully set up."

check_mailcow_unit_status --status