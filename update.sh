#!/bin/bash

# Pfad zum Repository-Verzeichnis
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Funktion: Systemd-Dateien überprüfen und reparieren
repair_systemd_services() {
    local backup_script="$REPO_DIR/Backup/mailcow-backup.sh"
    local ftp_script="$REPO_DIR/Upload/FTP-Upload.sh"
    local webdav_script="$REPO_DIR/Upload/WebDAV-Upload.sh"
    
    # Array mit den zu überprüfenden Services
    local services=(
        "/etc/systemd/system/mailcow-backup.service"
        "/etc/systemd/system/mailcow-ftp-upload.service"
        "/etc/systemd/system/mailcow-webdav-upload.service"
    )
    
    local needs_reload=false
    
    for service_file in "${services[@]}"; do
        if [ -f "$service_file" ]; then
            case "$service_file" in
                "/etc/systemd/system/mailcow-backup.service")
                    if grep -q "^ExecStart=" "$service_file" && ! grep -q "^ExecStart=/bin/bash $backup_script$" "$service_file"; then
                        echo "⚠️  Repariere $service_file"
                        sudo sed -i "s|^ExecStart=.*|ExecStart=/bin/bash $backup_script|" "$service_file"
                        needs_reload=true
                    fi
                    ;;
                "/etc/systemd/system/mailcow-ftp-upload.service")
                    if grep -q "^ExecStart=" "$service_file" && ! grep -q "^ExecStart=/bin/bash $ftp_script$" "$service_file"; then
                        echo "⚠️  Repariere $service_file"
                        sudo sed -i "s|^ExecStart=.*|ExecStart=/bin/bash $ftp_script|" "$service_file"
                        needs_reload=true
                    fi
                    ;;
                "/etc/systemd/system/mailcow-webdav-upload.service")
                    if grep -q "^ExecStart=" "$service_file" && ! grep -q "^ExecStart=/bin/bash $webdav_script$" "$service_file"; then
                        echo "⚠️  Repariere $service_file"
                        sudo sed -i "s|^ExecStart=.*|ExecStart=/bin/bash $webdav_script|" "$service_file"
                        needs_reload=true
                    fi
                    ;;
            esac
        fi
    done
    
    # Systemd neu laden wenn nötig
    if [ "$needs_reload" = true ]; then
        echo "Lade systemd neu..."
        sudo systemctl daemon-reload
        echo "✓ Systemd-Dateien aktualisiert"
    fi
}

echo "--- Mailcow-BackupV2 Auto-Updater ---"

# 1. Prüfen, ob wir in einem Git-Repo sind
if [ ! -d .git ]; then
    echo "Fehler: Kein Git-Repository gefunden. Update nicht möglich."
    exit 1
fi

# 2. Lokale Änderungen sichern (inkl. untracked Dateien)
STASH_NAME="Auto-update-stash-$(date +%s)"
STASH_CREATED=false

if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo "Speichere lokale Änderungen..."
    if git stash push --include-untracked -m "$STASH_NAME" &>/dev/null; then
        STASH_CREATED=true
    else
        echo "Fehler: Lokale Änderungen konnten nicht gesichert werden."
        exit 1
    fi
else
    echo "Keine lokalen Änderungen gefunden."
fi

# 4. Remote-Infos holen
echo "Prüfe auf Updates..."
git fetch origin main &>/dev/null

# 5. Vergleich: Lokal vs. Remote
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    echo "Ein Update ist verfügbar!"
    
    echo "Lade neue Version herunter..."
    git pull origin main
    
    if [ $? -eq 0 ]; then
        echo "✓ Update erfolgreich durchgeführt."
        
        # 6. Skripte ausführbar machen
        echo "Mache Scripts ausführbar..."
        find . -name "*.sh" -type f -exec chmod +x {} \;
        
        # 6b. Systemd-Dateien überprüfen und reparieren
        echo "Überprüfe systemd-Dateien..."
        repair_systemd_services
        
        # 7. Abhängigkeiten aktualisieren (optional)
        if [ -f "Dependencies/install_dependencies.sh" ]; then
            read -p "Möchtest du auch die Abhängigkeiten aktualisieren? (j/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Jj]$ ]]; then
                sudo bash "$REPO_DIR/Dependencies/install_dependencies.sh"
            fi
        fi
        
        echo "Update-Schritte abgeschlossen."
    else
        echo "Fehler beim Pull. Breche ab."
        if [ "$STASH_CREATED" = true ]; then
            echo "Stelle lokale Änderungen wieder her..."
            git stash pop &>/dev/null
        fi
        exit 1
    fi
else
    echo "✓ Dein Backup-Script ist bereits auf dem neuesten Stand."
fi

# 8. Lokale Änderungen wiederherstellen
if [ "$STASH_CREATED" = true ]; then
    echo "Wende lokale Änderungen wieder an..."
    git stash pop &>/dev/null
fi

echo "Fertig!"