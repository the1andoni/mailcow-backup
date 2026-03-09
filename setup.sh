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
mkdir -p "$CONFIG_DIR"

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
if [ -f "$CONFIG_DIR/ftp-config.sh.gpg" ] || [ -f "$CONFIG_DIR/webdav-config.sh.gpg" ]; then
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
    echo "Sie haben FTP gewählt."
    echo "Bitte geben Sie die FTP-Server-Adresse ein:"
    read -p "FTP-Server: " ftp_server
    echo "Bitte geben Sie Ihren FTP-Benutzernamen ein:"
    read -p "Benutzername: " ftp_user
    echo "Bitte geben Sie Ihr FTP-Passwort ein:"
    read -s -p "Passwort: " ftp_password
    echo "Bitte geben Sie den Fingerabdruck des FTP-Zertifikats ein:"
    read -p "Zertifikat-Fingerabdruck: " ftp_certificate_fingerprint
    echo

    # Vorherige unverschlüsselte Datei löschen, falls vorhanden
    rm -f "$CONFIG_DIR/ftp-config.sh"

    # Speichere die FTP-Konfiguration
    echo "FTP_SERVER=\"$ftp_server\"" > "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_USER=\"$ftp_user\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_PASSWORD=\"$ftp_password\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_CERTIFICATE_FINGERPRINT=\"$ftp_certificate_fingerprint\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "LOCAL_RETENTION=\"$local_retention\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "REMOTE_RETENTION=\"$remote_retention\"" >> "$CONFIG_DIR/ftp-config.sh"

    # Verschlüsseln der Konfigurationsdatei
    echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$CONFIG_DIR/ftp-config.sh.gpg" "$CONFIG_DIR/ftp-config.sh"
    rm -f "$CONFIG_DIR/ftp-config.sh"
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

echo "Setup abgeschlossen! Die systemd-Timer wurden erfolgreich eingerichtet."