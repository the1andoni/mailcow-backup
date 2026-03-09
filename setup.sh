#!/bin/bash

# Überprüfen, ob das Skript mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript mit sudo aus."
  exit 1
fi

CONFIG_DIR="$(dirname "$0")/Configs"
mkdir -p "$CONFIG_DIR"

echo "Willkommen zum Setup-Skript!"

# Passwort für die Verschlüsselung abfragen
echo "Bitte geben Sie ein Passwort für die Verschlüsselung der Konfigurationsdateien ein:"
read -s -p "GPG-Passwort: " gpg_password
echo
export GPG_TTY=$(tty) # Für GPG-Agent-Kompatibilität

# GPG-Agent initialisieren
echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output /dev/null <<< "Test"

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

    # Speichere die WebDAV-Konfiguration
    echo "WEBDAV_URL=\"$webdav_url\"" > "$CONFIG_DIR/webdav-config.sh"
    echo "WEBDAV_USER=\"$webdav_user\"" >> "$CONFIG_DIR/webdav-config.sh"
    echo "WEBDAV_PASSWORD=\"$webdav_password\"" >> "$CONFIG_DIR/webdav-config.sh"
    echo "LOCAL_RETENTION=\"$local_retention\"" >> "$CONFIG_DIR/webdav-config.sh"
    echo "REMOTE_RETENTION=\"$remote_retention\"" >> "$CONFIG_DIR/webdav-config.sh"

    # Verschlüsseln der Konfigurationsdatei
    echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$CONFIG_DIR/webdav-config.sh.gpg" "$CONFIG_DIR/webdav-config.sh"
    rm "$CONFIG_DIR/webdav-config.sh"

    # Cronjob für WebDAV-Upload einrichten
    echo "Richten Sie den Cronjob für den WebDAV-Upload ein."
    read -p "Wie oft soll das Backup hochgeladen werden? (z.B. '0 2 * * *' für täglich um 2 Uhr): " cron_schedule
    (crontab -l 2>/dev/null; echo "$cron_schedule bash $(pwd)/Upload/WebDAV-Upload.sh") | crontab -
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

    # Speichere die FTP-Konfiguration
    echo "FTP_SERVER=\"$ftp_server\"" > "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_USER=\"$ftp_user\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_PASSWORD=\"$ftp_password\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "FTP_CERTIFICATE_FINGERPRINT=\"$ftp_certificate_fingerprint\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "LOCAL_RETENTION=\"$local_retention\"" >> "$CONFIG_DIR/ftp-config.sh"
    echo "REMOTE_RETENTION=\"$remote_retention\"" >> "$CONFIG_DIR/ftp-config.sh"

    # Verschlüsseln der Konfigurationsdatei
    echo "$gpg_password" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$CONFIG_DIR/ftp-config.sh.gpg" "$CONFIG_DIR/ftp-config.sh"
    rm "$CONFIG_DIR/ftp-config.sh"

    # Cronjob für FTP-Upload einrichten
    echo "Richten Sie den Cronjob für den FTP-Upload ein."
    read -p "Wie oft soll das Backup hochgeladen werden? (z.B. '0 2 * * *' für täglich um 2 Uhr): " cron_schedule
    (crontab -l 2>/dev/null; echo "$cron_schedule bash $(pwd)/Upload/FTP-Upload.sh") | crontab -
fi

# Cronjob für das Backup-Skript einrichten
echo "Richten Sie den Cronjob für das Backup-Skript ein."
read -p "Wie oft soll das Backup erstellt werden? (z.B. '0 1 * * *' für täglich um 1 Uhr): " backup_cron_schedule
(crontab -l 2>/dev/null; echo "$backup_cron_schedule bash $(pwd)/mailcow-backup.sh") | crontab -

echo "Setup abgeschlossen! Die Cronjobs wurden erfolgreich eingerichtet."