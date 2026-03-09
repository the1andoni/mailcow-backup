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
source <(echo "$gpg_password" | gpg --quiet --batch --passphrase-fd 0 --decrypt "$CONFIG_DIR/ftp-config.sh.gpg")

# Variablen
DATE=$(date +"%Y-%m-%d")
BACKUP_DIR="/backup/mailcow"
TAR_FILE="$BACKUP_DIR/mailcow-backup-$DATE.tar.gz"

# Sicherstellen, dass das Backup-Verzeichnis existiert
sudo mkdir -p "$BACKUP_DIR"

# Backup per FTP hochladen
if [ -n "$FTP_CERTIFICATE_FINGERPRINT" ]; then
    echo "[+] Lade Backup per FTP mit TLS hoch..."
    curl --pinnedpubkey "$FTP_CERTIFICATE_FINGERPRINT" -u "$FTP_USER:$FTP_PASSWORD" -T "$TAR_FILE" "ftp://$FTP_SERVER$FTP_UPLOAD_DIR"
else
    echo "[⚠️] Kein Zertifikat-Fingerabdruck angegeben. Lade Backup ohne TLS hoch..."
    curl -u "$FTP_USER:$FTP_PASSWORD" -T "$TAR_FILE" "ftp://$FTP_SERVER$FTP_UPLOAD_DIR"
fi

# Prüfen, ob der Upload erfolgreich war
if [ $? -eq 0 ]; then
    echo "[✅] Backup erfolgreich per FTP hochgeladen!"
else
    echo "❌ Fehler: Upload per FTP fehlgeschlagen!"
    exit 1
fi

# Alte Backups lokal löschen
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$LOCAL_RETENTION" -exec rm -f {} \;

# Alte Backups remote löschen
lftp -u "$FTP_USER,$FTP_PASSWORD" "$FTP_SERVER" <<EOF
cd $FTP_UPLOAD_DIR
# Lösche Dateien, die älter als REMOTE_RETENTION Tage
mrm $(find . -type f -mtime +"$REMOTE_RETENTION")
bye
EOF

else
    echo "[⚠️] Kein Löschintervall definiert. Es werden keine alten Backups gelöscht."
fi