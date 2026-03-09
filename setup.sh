#!/bin/bash

# Überprüfen, ob das Skript mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript mit sudo aus."
  exit 1
fi

# Pfad zum Repository-Verzeichnis
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Prüfen auf verfügbare Updates
echo "Prüfe auf verfügbare Updates..."
if [ -d .git ]; then
  git fetch origin main &>/dev/null
  
  LOCAL=$(git rev-parse HEAD)
  REMOTE=$(git rev-parse origin/main)
  
  if [ "$LOCAL" != "$REMOTE" ]; then
    echo ""
    echo "⚠️  Ein Update ist verfügbar!"
    echo "Es wird empfohlen, zuerst das Repository zu aktualisieren."
    echo ""
    read -p "Möchten Sie jetzt aktualisieren? (j/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Jj]$ ]]; then
      echo "Führe Update durch..."
      SETUP_STASH_NAME="setup-stash-$(date +%s)"
      SETUP_STASH_CREATED=false
      if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        if git stash push --include-untracked -m "$SETUP_STASH_NAME" &>/dev/null; then
          SETUP_STASH_CREATED=true
        else
          echo "Fehler: Lokale Änderungen konnten nicht gesichert werden."
          exit 1
        fi
      fi

      git pull origin main &>/dev/null
      if [ $? -eq 0 ]; then
        echo "✓ Update erfolgreich durchgeführt."
        # Stash-Änderungen zurückfahren (falls vorhanden)
        if [ "$SETUP_STASH_CREATED" = true ]; then
          git stash pop &>/dev/null
        fi
        # Script neu laden
        echo "Starte Setup neu..."
        exec "$0" "$@"
      else
        echo "Fehler beim Update. Breche ab."
        if [ "$SETUP_STASH_CREATED" = true ]; then
          git stash pop &>/dev/null
        fi
        exit 1
      fi
    fi
  fi
else
  echo "Keine Git-Repository gefunden. Überspringe Update-Prüfung."
fi

CONFIG_DIR="$(dirname "$0")/Configs"
SCRIPT_DIR="$(dirname "$0")"
BACKUP_SCRIPT="$SCRIPT_DIR/Backup/mailcow-backup.sh"
FTP_UPLOAD_SCRIPT="$SCRIPT_DIR/Upload/FTP-Upload.sh"
WEBDAV_UPLOAD_SCRIPT="$SCRIPT_DIR/Upload/WebDAV-Upload.sh"
NAS_UPLOAD_SCRIPT="$SCRIPT_DIR/Upload/NAS-Upload.sh"
S3_UPLOAD_SCRIPT="$SCRIPT_DIR/Upload/S3-Upload.sh"
mkdir -p "$CONFIG_DIR"

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

  echo "Fehlende Abhängigkeiten für $feature: ${missing[*]}"
  read -p "Möchten Sie jetzt versuchen, fehlende Abhängigkeiten zu installieren? (y/n) " install_choice
  if [ "$install_choice" = "y" ]; then
    if [ -f "$REPO_DIR/Dependencies/install_dependencies.sh" ]; then
      sudo bash "$REPO_DIR/Dependencies/install_dependencies.sh"
    else
      echo "Fehler: install_dependencies.sh nicht gefunden."
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
    echo "Fehler: Diese Abhängigkeiten fehlen weiterhin: ${missing[*]}"
    echo "Bitte installieren Sie diese manuell und starten Sie setup.sh erneut."
    return 1
  fi

  return 0
}

echo "Willkommen zum Setup-Skript!"

# Passwort für die Verschlüsselung abfragen
echo "Bitte geben Sie ein Passwort für die Verschlüsselung der Konfigurationsdateien ein:"
read -s -p "GPG-Passwort: " gpg_password
echo
export GPG_TTY=$(tty) # Für GPG-Agent-Kompatibilität

# GPG-Agent initialisieren
echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output /dev/null <<< "Test"

# GPG-Passwort sicher in /root/.mailcow-gpg-pass speichern
echo "$gpg_password" | sudo tee /root/.mailcow-gpg-pass > /dev/null
sudo chmod 600 /root/.mailcow-gpg-pass
echo "Das GPG-Passwort wurde sicher in /root/.mailcow-gpg-pass gespeichert."

# Prüfen, ob bestehende Konfigurationen überschrieben werden sollen
if [ -f "$CONFIG_DIR/ftp-config.sh.gpg" ] || [ -f "$CONFIG_DIR/webdav-config.sh.gpg" ] || [ -f "$CONFIG_DIR/nas-config.sh.gpg" ] || [ -f "$CONFIG_DIR/s3-config.sh.gpg" ]; then
  echo "Es existieren bereits Konfigurationsdateien. Möchten Sie diese überschreiben? (y/n)"
  read -p "Eingabe: " overwrite
  if [ "$overwrite" != "y" ]; then
    echo "Setup abgebrochen."
    exit 0
  fi
fi

# Backup-Aufbewahrungszeit abfragen
echo "Wie viele Tage sollen Backups lokal aufbewahrt werden?"
read -p "Lokal (in Tagen): " local_retention
echo "Wie viele Tage sollen Backups auf dem Remote-Server (WebDAV/FTP) aufbewahrt werden?"
read -p "Remote (in Tagen): " remote_retention

# Backup-Methoden konfigurieren
echo "Welche Backup-Methoden möchten Sie einrichten?"
echo "1) WebDAV"
echo "2) FTP"
echo "3) Beide"
read -p "Bitte wählen Sie eine Option (1, 2 oder 3): " export_option

if [ "$export_option" == "1" ] || [ "$export_option" == "3" ]; then
    ensure_dependencies "WebDAV" gpg curl || exit 1
    echo "Sie haben WebDAV gewählt."
    echo "Bitte geben Sie die WebDAV-URL ein (z. B. https://webdav-server/path/):"
    read -p "WebDAV-URL: " webdav_url
    echo "Bitte geben Sie Ihren WebDAV-Benutzernamen ein:"
    read -p "Benutzername: " webdav_user
    echo "Bitte geben Sie Ihr WebDAV-Passwort ein:"
    read -s -p "Passwort: " webdav_password
    echo

    # Vorherige unverschlüsselte Datei löschen, falls vorhanden
    rm -f "$CONFIG_DIR/webdav-config.sh"

    # Speichere die WebDAV-Konfiguration
    echo "WEBDAV_URL=\"$webdav_url\"" > "$CONFIG_DIR/webdav-config.sh"
    echo "WEBDAV_USER=\"$webdav_user\"" >> "$CONFIG_DIR/webdav-config.sh"
    echo "WEBDAV_PASSWORD=\"$webdav_password\"" >> "$CONFIG_DIR/webdav-config.sh"
    echo "LOCAL_RETENTION=\"$local_retention\"" >> "$CONFIG_DIR/webdav-config.sh"
    echo "REMOTE_RETENTION=\"$remote_retention\"" >> "$CONFIG_DIR/webdav-config.sh"

    # Verschlüsseln der Konfigurationsdatei
    echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$CONFIG_DIR/webdav-config.sh.gpg" "$CONFIG_DIR/webdav-config.sh"
    rm -f "$CONFIG_DIR/webdav-config.sh"
fi

if [ "$export_option" == "2" ] || [ "$export_option" == "3" ]; then
    ensure_dependencies "FTP/SFTP" gpg curl || exit 1
    echo "Sie haben FTP/SFTP gewählt."
    echo "Welches Protokoll möchten Sie verwenden?"
    echo "1) FTP"
    echo "2) SFTP"
    read -p "Bitte wählen Sie eine Option (1 oder 2): " ftp_protocol_option

    case "$ftp_protocol_option" in
      2)
        ftp_protocol="sftp"
        ;;
      *)
        ftp_protocol="ftp"
        ;;
    esac

    echo "Bitte geben Sie die Server-Adresse ein (ohne Protokoll, z. B. backup.example.com):"
    read -p "Server: " ftp_server
    echo "Bitte geben Sie den Upload-Zielpfad ein (z. B. /mailcow-backups):"
    read -p "Upload-Pfad: " ftp_upload_dir
    echo "Bitte geben Sie Ihren Benutzernamen ein:"
    read -p "Benutzername: " ftp_user
    echo "Bitte geben Sie Ihr Passwort ein:"
    read -s -p "Passwort: " ftp_password

    ftp_certificate_fingerprint=""
    if [ "$ftp_protocol" = "ftp" ]; then
      echo "Optional: Bitte geben Sie den Fingerabdruck des FTP-Zertifikats ein (oder leer lassen):"
      read -p "Zertifikat-Fingerabdruck: " ftp_certificate_fingerprint
    fi
    echo

    # Vorherige unverschlüsselte Datei löschen, falls vorhanden
    rm -f "$CONFIG_DIR/ftp-config.sh"

    # Speichere die FTP-Konfiguration
    echo "FTP_PROTOCOL=\"$ftp_protocol\"" > "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_SERVER=\"$ftp_server\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_UPLOAD_DIR=\"$ftp_upload_dir\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_USER=\"$ftp_user\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_PASSWORD=\"$ftp_password\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_CERTIFICATE_FINGERPRINT=\"$ftp_certificate_fingerprint\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "LOCAL_RETENTION=\"$local_retention\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "REMOTE_RETENTION=\"$remote_retention\"" >> "$CONFIG_DIR/ftp-config.sh"

    # Verschlüsseln der Konfigurationsdatei
    echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$CONFIG_DIR/ftp-config.sh.gpg" "$CONFIG_DIR/ftp-config.sh"
    rm -f "$CONFIG_DIR/ftp-config.sh"
fi

  echo "Möchten Sie einen NAS-Upload einrichten? (y/n)"
  read -p "Eingabe: " nas_config_choice
  if [ "$nas_config_choice" == "y" ]; then
    ensure_dependencies "NAS" gpg mountpoint || exit 1
    echo "Bitte geben Sie den lokalen Mount-Pfad des NAS ein (z. B. /mnt/backup-nas):"
    read -p "NAS-Mount-Pfad: " nas_mount_path
    echo "Bitte geben Sie den Zielordner auf dem NAS ein (z. B. /mailcow):"
    read -p "NAS-Zielordner: " nas_upload_dir

    rm -f "$CONFIG_DIR/nas-config.sh"
    echo "NAS_MOUNT_PATH=\"$nas_mount_path\"" > "$CONFIG_DIR/nas-config.sh"
    echo "NAS_UPLOAD_DIR=\"$nas_upload_dir\"" >> "$CONFIG_DIR/nas-config.sh"
    echo "LOCAL_RETENTION=\"$local_retention\"" >> "$CONFIG_DIR/nas-config.sh"
    echo "REMOTE_RETENTION=\"$remote_retention\"" >> "$CONFIG_DIR/nas-config.sh"

    echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$CONFIG_DIR/nas-config.sh.gpg" "$CONFIG_DIR/nas-config.sh"
    rm -f "$CONFIG_DIR/nas-config.sh"
  fi

  echo "Möchten Sie einen S3-Upload einrichten? (y/n)"
  read -p "Eingabe: " s3_config_choice
  if [ "$s3_config_choice" == "y" ]; then
    ensure_dependencies "S3" gpg aws || exit 1
    echo "Bitte geben Sie den S3-Bucket-Namen ein (z. B. mein-backup-bucket):"
    read -p "S3-Bucket: " s3_bucket
    echo "Optional: S3-Prefix im Bucket (z. B. mailcow, leer lassen für Root):"
    read -p "S3-Prefix: " s3_prefix
    echo "Optional: S3-Endpoint für S3-kompatible Dienste (z. B. https://s3.eu-central-1.amazonaws.com):"
    read -p "S3-Endpoint: " s3_endpoint
    echo "Bitte geben Sie die AWS Access Key ID ein:"
    read -p "Access Key ID: " aws_access_key_id
    echo "Bitte geben Sie den AWS Secret Access Key ein:"
    read -s -p "Secret Access Key: " aws_secret_access_key
    echo
    echo "Bitte geben Sie die AWS Region ein (z. B. eu-central-1):"
    read -p "Region: " aws_region

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
  fi

# Systemd-Timer für Backup einrichten
echo "Wie häufig soll das Backup ausgeführt werden?"
echo "1) Täglich"
echo "2) Wöchentlich"
echo "3) Monatlich"
read -p "Bitte wählen Sie eine Option (1, 2 oder 3): " frequency

case $frequency in
  1)
    echo "Bitte geben Sie die Uhrzeit für das tägliche Backup an (z. B. 02:00):"
    read -p "Backup-Zeit: " backup_time
    schedule="*-*-* ${backup_time}:00"
    ;;
  2)
    echo "Bitte geben Sie den Wochentag und die Uhrzeit für das wöchentliche Backup an (z. B. Sun 02:00):"
    read -p "Backup-Zeit: " backup_time
    schedule="${backup_time}:00"
    ;;
  3)
    echo "Bitte geben Sie den Tag des Monats und die Uhrzeit für das monatliche Backup an (z. B. 1 02:00):"
    read -p "Backup-Zeit: " backup_time
    schedule="*-*-${backup_time}:00"
    ;;
  *)
    echo "Ungültige Auswahl. Standardmäßig wird das Backup täglich um 02:00 ausgeführt."
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

# Systemd-Timer für FTP-Upload einrichten
echo "Möchten Sie einen automatischen FTP-Upload einrichten? (y/n)"
read -p "Eingabe: " ftp_upload_choice
if [ "$ftp_upload_choice" == "y" ]; then
    echo "Wie häufig soll der FTP-Upload ausgeführt werden?"
    echo "1) Täglich"
    echo "2) Wöchentlich"
    echo "3) Monatlich"
    read -p "Bitte wählen Sie eine Option (1, 2 oder 3): " ftp_frequency

    case $ftp_frequency in
      1)
        echo "Bitte geben Sie die Uhrzeit für den täglichen FTP-Upload an (z. B. 03:00):"
        read -p "FTP-Upload-Zeit: " ftp_upload_time
        ftp_schedule="*-*-* ${ftp_upload_time}:00"
        ;;
      2)
        echo "Bitte geben Sie den Wochentag und die Uhrzeit für den wöchentlichen FTP-Upload an (z. B. Sun 03:00):"
        read -p "FTP-Upload-Zeit: " ftp_upload_time
        ftp_schedule="${ftp_upload_time}:00"
        ;;
      3)
        echo "Bitte geben Sie den Tag des Monats und die Uhrzeit für den monatlichen FTP-Upload an (z. B. 1 03:00):"
        read -p "FTP-Upload-Zeit: " ftp_upload_time
        ftp_schedule="*-*-${ftp_upload_time}:00"
        ;;
      *)
        echo "Ungültige Auswahl. Standardmäßig wird der FTP-Upload täglich um 03:00 ausgeführt."
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

# Systemd-Timer für WebDAV-Upload einrichten
echo "Möchten Sie einen automatischen WebDAV-Upload einrichten? (y/n)"
read -r webdav_upload
if [[ "$webdav_upload" =~ ^[Yy]$ ]]; then
  echo "Wie häufig soll der WebDAV-Upload ausgeführt werden?"
  echo "1) Täglich"
  echo "2) Wöchentlich"
  echo "3) Monatlich"
  read -p "Bitte wählen Sie eine Option (1, 2 oder 3): " webdav_frequency

  case $webdav_frequency in
    1)
      echo "Bitte geben Sie die Uhrzeit für den täglichen WebDAV-Upload an (z. B. 04:00):"
      read -p "WebDAV-Upload-Zeit: " webdav_upload_time
      webdav_schedule="*-*-* ${webdav_upload_time}:00"
      ;;
    2)
      echo "Bitte geben Sie den Wochentag und die Uhrzeit für den wöchentlichen WebDAV-Upload an (z. B. Sun 04:00):"
      read -p "WebDAV-Upload-Zeit: " webdav_upload_time
      webdav_schedule="${webdav_upload_time}:00"
      ;;
    3)
      echo "Bitte geben Sie den Tag des Monats und die Uhrzeit für den monatlichen WebDAV-Upload an (z. B. 1 04:00):"
      read -p "WebDAV-Upload-Zeit: " webdav_upload_time
      webdav_schedule="*-*-${webdav_upload_time}:00"
      ;;
    *)
      echo "Ungültige Auswahl. Standardmäßig wird der WebDAV-Upload täglich um 04:00 ausgeführt."
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

# Systemd-Timer für NAS-Upload einrichten
if [ -f "$CONFIG_DIR/nas-config.sh.gpg" ]; then
echo "Möchten Sie einen automatischen NAS-Upload einrichten? (y/n)"
read -p "Eingabe: " nas_upload_choice
if [ "$nas_upload_choice" == "y" ]; then
    echo "Wie häufig soll der NAS-Upload ausgeführt werden?"
    echo "1) Täglich"
    echo "2) Wöchentlich"
    echo "3) Monatlich"
    read -p "Bitte wählen Sie eine Option (1, 2 oder 3): " nas_frequency

    case $nas_frequency in
      1)
        echo "Bitte geben Sie die Uhrzeit für den täglichen NAS-Upload an (z. B. 05:00):"
        read -p "NAS-Upload-Zeit: " nas_upload_time
        nas_schedule="*-*-* ${nas_upload_time}:00"
        ;;
      2)
        echo "Bitte geben Sie den Wochentag und die Uhrzeit für den wöchentlichen NAS-Upload an (z. B. Sun 05:00):"
        read -p "NAS-Upload-Zeit: " nas_upload_time
        nas_schedule="${nas_upload_time}:00"
        ;;
      3)
        echo "Bitte geben Sie den Tag des Monats und die Uhrzeit für den monatlichen NAS-Upload an (z. B. 1 05:00):"
        read -p "NAS-Upload-Zeit: " nas_upload_time
        nas_schedule="*-*-${nas_upload_time}:00"
        ;;
      *)
        echo "Ungültige Auswahl. Standardmäßig wird der NAS-Upload täglich um 05:00 ausgeführt."
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

# Systemd-Timer für S3-Upload einrichten
  if [ -f "$CONFIG_DIR/s3-config.sh.gpg" ]; then
  echo "Möchten Sie einen automatischen S3-Upload einrichten? (y/n)"
  read -p "Eingabe: " s3_upload_choice
  if [ "$s3_upload_choice" == "y" ]; then
    echo "Wie häufig soll der S3-Upload ausgeführt werden?"
    echo "1) Täglich"
    echo "2) Wöchentlich"
    echo "3) Monatlich"
    read -p "Bitte wählen Sie eine Option (1, 2 oder 3): " s3_frequency

    case $s3_frequency in
      1)
        echo "Bitte geben Sie die Uhrzeit für den täglichen S3-Upload an (z. B. 06:00):"
        read -p "S3-Upload-Zeit: " s3_upload_time
        s3_schedule="*-*-* ${s3_upload_time}:00"
        ;;
      2)
        echo "Bitte geben Sie den Wochentag und die Uhrzeit für den wöchentlichen S3-Upload an (z. B. Sun 06:00):"
        read -p "S3-Upload-Zeit: " s3_upload_time
        s3_schedule="${s3_upload_time}:00"
        ;;
      3)
        echo "Bitte geben Sie den Tag des Monats und die Uhrzeit für den monatlichen S3-Upload an (z. B. 1 06:00):"
        read -p "S3-Upload-Zeit: " s3_upload_time
        s3_schedule="*-*-${s3_upload_time}:00"
        ;;
      *)
        echo "Ungültige Auswahl. Standardmäßig wird der S3-Upload täglich um 06:00 ausgeführt."
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

echo "Setup abgeschlossen! Die systemd-Timer wurden erfolgreich eingerichtet."