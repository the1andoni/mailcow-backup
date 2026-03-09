#!/bin/bash

# Überprüfen, ob das Skript mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript mit sudo aus."
  exit 1
fi

# Konfigurationsdatei entschlüsseln und laden
CONFIG_DIR="$(dirname "$0")/../Configs"
echo "Bitte geben Sie das GPG-Passwort ein:"
read -s -p "Passwort: " gpg_password
echo
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/webdav-config.sh.gpg")

# Variablen
BACKUP_DIR="/backup/mailcow"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
TAR_FILE="$BACKUP_DIR/mailcow-backup-$DATE.tar.gz"

# Sicherstellen, dass das Backup-Verzeichnis existiert
sudo mkdir -p "$BACKUP_DIR"

# Backup auf WebDAV hochladen
echo "[+] Lade Backup auf WebDAV-Server hoch..."
UPLOAD_RESPONSE=$(curl -u "$WEBDAV_USER:$WEBDAV_PASSWORD" -T "$TAR_FILE" "$WEBDAV_URL" --silent --write-out "%{http_code}")

# Prüfen, ob der Upload erfolgreich war
if [ "$UPLOAD_RESPONSE" -eq 201 ] || [ "$UPLOAD_RESPONSE" -eq 204 ]; then
    echo "[✅] Backup erfolgreich auf WebDAV-Server hochgeladen!"
else
    echo "❌ Fehler: Upload fehlgeschlagen (HTTP-Code: $UPLOAD_RESPONSE)"
    exit 1
fi

# Alte Backups lokal löschen
if [ -n "$LOCAL_RETENTION" ]; then
    echo "[+] Lösche lokale Backups, die älter als $LOCAL_RETENTION Tage sind..."
    find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;
    echo "[✅] Alte lokale Backups erfolgreich gelöscht."
else
    echo "[⚠️] Kein Löschintervall für lokale Backups definiert. Es werden keine alten Backups gelöscht."
fi

# Alte Backups auf dem WebDAV-Server löschen
if [ -n "$REMOTE_RETENTION" ]; then
    echo "[+] Lösche Backups auf dem WebDAV-Server, die älter als $REMOTE_RETENTION Tage sind..."
    # Liste Dateien auf dem WebDAV-Server
    curl -u "$WEBDAV_USER:$WEBDAV_PASSWORD" -X PROPFIND --data '<?xml version="1.0"?>
    <d:propfind xmlns:d="DAV:">
      <d:prop>
        <d:getlastmodified/>
      </d:prop>
    </d:propfind>' "$WEBDAV_URL" --silent | grep -oP '(?<=<d:href>).*?(?=</d:href>)' | while read -r file; do
        # Extrahiere das Änderungsdatum der Datei
        file_date=$(curl -u "$WEBDAV_USER:$WEBDAV_PASSWORD" -I "$WEBDAV_URL$file" --silent | grep -i "Last-Modified" | awk '{print $3, $4, $5}')
        if [ -n "$file_date" ]; then
            # Berechne das Alter der Datei
            file_timestamp=$(date -d "$file_date" +%s)
            current_timestamp=$(date +%s)
            age_days=$(( (current_timestamp - file_timestamp) / 86400 ))
            if [ "$age_days" -gt "$REMOTE_RETENTION" ]; then
                echo "[+] Lösche Datei: $file (Alter: $age_days Tage)"
                curl -u "$WEBDAV_USER:$WEBDAV_PASSWORD" -X DELETE "$WEBDAV_URL$file"
            fi
        fi
    done
    echo "[✅] Alte Backups auf dem WebDAV-Server erfolgreich gelöscht."
else
    echo "[⚠️] Kein Löschintervall für Remote-Backups definiert. Es werden keine alten Backups gelöscht."
fi