#!/bin/bash

# Path to repository directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Flags for self-update and stash status
SELF_UPDATE_DONE="${1:-}"
STASH_WAS_CREATED="${2:-false}"

# Function: Check and repair systemd files
repair_systemd_services() {
    local backup_script="$REPO_DIR/Backup/mailcow-backup.sh"
    local ftp_script="$REPO_DIR/Upload/FTP-Upload.sh"
    local webdav_script="$REPO_DIR/Upload/WebDAV-Upload.sh"
    local nas_script="$REPO_DIR/Upload/NAS-Upload.sh"
    local s3_script="$REPO_DIR/Upload/S3-Upload.sh"
    
    # Array of services to check
    local services=(
        "/etc/systemd/system/mailcow-backup.service"
        "/etc/systemd/system/mailcow-ftp-upload.service"
        "/etc/systemd/system/mailcow-webdav-upload.service"
        "/etc/systemd/system/mailcow-nas-upload.service"
        "/etc/systemd/system/mailcow-s3-upload.service"
    )
    
    local needs_reload=false
    
    for service_file in "${services[@]}"; do
        if [ -f "$service_file" ]; then
            case "$service_file" in
                "/etc/systemd/system/mailcow-backup.service")
                    if grep -q "^ExecStart=" "$service_file" && ! grep -q "^ExecStart=/bin/bash $backup_script$" "$service_file"; then
                        echo "⚠️  Repairing $service_file"
                        sudo sed -i "s|^ExecStart=.*|ExecStart=/bin/bash $backup_script|" "$service_file"
                        needs_reload=true
                    fi
                    ;;
                "/etc/systemd/system/mailcow-ftp-upload.service")
                    if grep -q "^ExecStart=" "$service_file" && ! grep -q "^ExecStart=/bin/bash $ftp_script$" "$service_file"; then
                        echo "⚠️  Repairing $service_file"
                        sudo sed -i "s|^ExecStart=.*|ExecStart=/bin/bash $ftp_script|" "$service_file"
                        needs_reload=true
                    fi
                    ;;
                "/etc/systemd/system/mailcow-webdav-upload.service")
                    if grep -q "^ExecStart=" "$service_file" && ! grep -q "^ExecStart=/bin/bash $webdav_script$" "$service_file"; then
                        echo "⚠️  Repairing $service_file"
                        sudo sed -i "s|^ExecStart=.*|ExecStart=/bin/bash $webdav_script|" "$service_file"
                        needs_reload=true
                    fi
                    ;;
                "/etc/systemd/system/mailcow-nas-upload.service")
                    if grep -q "^ExecStart=" "$service_file" && ! grep -q "^ExecStart=/bin/bash $nas_script$" "$service_file"; then
                        echo "⚠️  Repairing $service_file"
                        sudo sed -i "s|^ExecStart=.*|ExecStart=/bin/bash $nas_script|" "$service_file"
                        needs_reload=true
                    fi
                    ;;
                "/etc/systemd/system/mailcow-s3-upload.service")
                    if grep -q "^ExecStart=" "$service_file" && ! grep -q "^ExecStart=/bin/bash $s3_script$" "$service_file"; then
                        echo "⚠️  Repairing $service_file"
                        sudo sed -i "s|^ExecStart=.*|ExecStart=/bin/bash $s3_script|" "$service_file"
                        needs_reload=true
                    fi
                    ;;
            esac
        fi
    done
    
    # Reload systemd if necessary
    if [ "$needs_reload" = true ]; then
        echo "Reloading systemd..."
        sudo systemctl daemon-reload
        echo "✓ Systemd files updated"
    fi
}

echo "--- Mailcow-BackupV2 Auto-Updater ---"

# 1. Check if we're in a Git repository
if [ ! -d .git ]; then
    echo "Error: No Git repository found. Update not possible."
    exit 1
fi

# 2. Save local changes (incl. untracked files)
# If restarted after self-update, use existing stash info
if [ "$STASH_WAS_CREATED" = "true" ]; then
    STASH_CREATED=true
    echo "Local changes already saved."
else
    STASH_NAME="Auto-update-stash-$(date +%s)"
    STASH_CREATED=false
    
    if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo "Saving local changes..."
        if git stash push --include-untracked -m "$STASH_NAME" &>/dev/null; then
            STASH_CREATED=true
        else
            echo "Error: Could not save local changes."
            exit 1
        fi
    else
        echo "No local changes found."
    fi
fi

# 3. Fetch remote info
echo "Checking for updates..."
git fetch origin main &>/dev/null

# 4. Compare: Local vs. Remote
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✓ Your backup script is already up to date."
    if [ "$STASH_CREATED" = true ]; then
        echo "Restoring local changes..."
        git stash pop &>/dev/null
    fi
    exit 0
fi

# ========================================
# PHASE 1: Self-update of update.sh
# ========================================
if [ "$SELF_UPDATE_DONE" != "--self-updated" ]; then
    # Check if update.sh itself was changed
    if git diff --name-only HEAD..origin/main | grep -q "^update.sh$"; then
        echo ""
        echo "⚡ Update script itself has an update!"
        echo ""
        echo "=== Changes in update.sh ==="
        git log --oneline --no-decorate HEAD..origin/main -- update.sh
        echo ""
        git diff HEAD..origin/main -- update.sh | head -30
        echo "==========================="
        echo ""
        
        read -p "Do you want to update the update script now? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Update cancelled."
            if [ "$STASH_CREATED" = true ]; then
                echo "Restoring local changes..."
                git stash pop &>/dev/null
            fi
            exit 0
        fi
        
        echo "Updating update.sh..."
        git checkout origin/main -- update.sh
        chmod +x update.sh
        
        echo "✓ Update script updated. Restarting..."
        echo ""
        
        # Restart script with flags (pass stash info)
        exec bash "$REPO_DIR/update.sh" "--self-updated" "$STASH_CREATED"
    fi
fi

# ========================================
# PHASE 2: Complete update
# ========================================
echo ""
echo "📦 Complete update available!"
echo ""
echo "=== Changes in update ==="

# Show commit messages
echo ""
echo "📝 Commits:"
git log --oneline --no-decorate HEAD..origin/main

echo ""
echo "📂 Changed files:"
git diff --name-status HEAD..origin/main | head -20

echo ""
echo "==========================="
echo ""

# Ask user if update should be performed
read -p "Do you want to install the complete update now? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update cancelled."
    if [ "$STASH_CREATED" = true ]; then
        echo "Restoring local changes..."
        git stash pop &>/dev/null
    fi
    exit 0
fi

echo "Downloading new version..."
git pull origin main

if [ $? -eq 0 ]; then
    echo "✓ Update successfully completed."
    
    # 6. Make scripts executable
    echo "Making scripts executable..."
    find . -name "*.sh" -type f -exec chmod +x {} \;
    
    # 6b. Check and repair systemd files
    echo "Checking systemd files..."
    repair_systemd_services
    
    # 7. Update dependencies (optional)
    if [ -f "Dependencies/install_dependencies.sh" ]; then
        read -p "Do you also want to update dependencies? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo bash "$REPO_DIR/Dependencies/install_dependencies.sh"
        fi
    fi
    
    echo "Update steps completed."
else
    echo "Error during pull. Aborting."
    if [ "$STASH_CREATED" = true ]; then
        echo "Restoring local changes..."
        git stash pop &>/dev/null
    fi
    exit 1
fi

# 8. Restore local changes
if [ "$STASH_CREATED" = true ]; then
    echo "Applying local changes..."
    git stash pop &>/dev/null
fi

echo ""
echo "✓ Done!"