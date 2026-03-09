#!/bin/bash

# Path to repository directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Flags for self-update and stash status
SELF_UPDATE_DONE=""
STASH_WAS_CREATED="false"
TARGET_BRANCH=""

# Function: Show usage information
show_usage() {
    echo "Usage: $0 [--main|--v3|--v2] [--help]"
    echo ""
    echo "Version flags:"
    echo "  --main    Switch/update to main branch"
    echo "  --v3      Switch/update to V3 branch"
    echo "  --v2      Switch/update to V2-LEGACY branch"
    echo ""
    echo "Rules:"
    echo "  - Upgrades are allowed (V2-LEGACY -> V3 -> main)"
    echo "  - Downgrades are blocked (exception: main -> V3 is allowed with confirmation)"
}

# Function: Map branch names to version ranks
branch_rank() {
    case "$1" in
        "V2-LEGACY") echo 1 ;;
        "V3") echo 2 ;;
        "main") echo 3 ;;
        *) echo 0 ;;
    esac
}

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --main|main)
            TARGET_BRANCH="main"
            ;;
        --v3|V3|v3)
            TARGET_BRANCH="V3"
            ;;
        --v2|V2|v2)
            TARGET_BRANCH="V2-LEGACY"
            ;;
        --self-updated)
            SELF_UPDATE_DONE="--self-updated"
            ;;
        --stash-created=true)
            STASH_WAS_CREATED="true"
            ;;
        --stash-created=false)
            STASH_WAS_CREATED="false"
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$arg'"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

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

echo "--- Mailcow-Backup Auto-Updater ---"

# 1. Check if we're in a Git repository
if [ ! -d .git ]; then
    echo "Error: No Git repository found. Update not possible."
    exit 1
fi

# 2. Detect current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ -z "$CURRENT_BRANCH" ]; then
    echo "Error: Could not detect current branch."
    exit 1
fi

echo "Current branch: $CURRENT_BRANCH"

# Requested branch switch (optional)
if [ -n "$TARGET_BRANCH" ] && [ "$TARGET_BRANCH" != "$CURRENT_BRANCH" ]; then
    CURRENT_RANK=$(branch_rank "$CURRENT_BRANCH")
    TARGET_RANK=$(branch_rank "$TARGET_BRANCH")
    ALLOW_SPECIAL_DOWNGRADE=false

    # Allow a controlled downgrade from main to V3.
    if [ "$CURRENT_BRANCH" = "main" ] && [ "$TARGET_BRANCH" = "V3" ]; then
        ALLOW_SPECIAL_DOWNGRADE=true
    fi

    # Block downgrades between known release branches
    if [ "$CURRENT_RANK" -gt 0 ] && [ "$TARGET_RANK" -gt 0 ] && [ "$TARGET_RANK" -lt "$CURRENT_RANK" ] && [ "$ALLOW_SPECIAL_DOWNGRADE" != true ]; then
        echo "Error: Downgrade not allowed: $CURRENT_BRANCH -> $TARGET_BRANCH"
        echo "Allowed upgrade path: V2-LEGACY -> V3 -> main"
        echo "Allowed downgrade exception: main -> V3"
        exit 1
    fi

    if [ "$ALLOW_SPECIAL_DOWNGRADE" = true ]; then
        echo "⚠️  You requested a downgrade from main to V3."
        echo "   This is supported, but local custom changes may need manual adjustment afterwards."
        read -p "Continue with downgrade to V3? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Downgrade cancelled."
            exit 0
        fi
    fi

    echo "Requested target branch: $TARGET_BRANCH"
fi

# Show branch-specific information
case "$CURRENT_BRANCH" in
    main)
        echo "⚠️  WARNING: You are on the development branch!"
        echo "   This branch may contain unstable code."
        echo "   For production use, consider switching to the V3 branch."
        echo ""
        ;;
    V3)
        echo "✓ You are on the stable release track."
        echo ""
        ;;
    V2-LEGACY)
        echo "⚠️  You are on the legacy v2.x support track."
        echo "   This branch receives security fixes only."
        echo "   Consider migrating to V3 for new features and improvements."
        echo ""
        ;;
esac

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

# Optional branch switch after stash handling
if [ -n "$TARGET_BRANCH" ] && [ "$TARGET_BRANCH" != "$CURRENT_BRANCH" ]; then
    echo "Switching branch: $CURRENT_BRANCH -> $TARGET_BRANCH"
    git fetch origin "$TARGET_BRANCH" &>/dev/null

    if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
        if ! git checkout "$TARGET_BRANCH" &>/dev/null; then
            echo "Error: Could not switch to branch '$TARGET_BRANCH'."
            if [ "$STASH_CREATED" = true ]; then
                echo "Restoring local changes..."
                git stash pop &>/dev/null
            fi
            exit 1
        fi
    else
        if ! git checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH" &>/dev/null; then
            echo "Error: Branch '$TARGET_BRANCH' not found on origin."
            if [ "$STASH_CREATED" = true ]; then
                echo "Restoring local changes..."
                git stash pop &>/dev/null
            fi
            exit 1
        fi
    fi

    CURRENT_BRANCH="$TARGET_BRANCH"
    echo "✓ Now on branch: $CURRENT_BRANCH"
fi

# 3. Fetch remote info
echo "Checking for updates..."
git fetch origin "$CURRENT_BRANCH" &>/dev/null

# 4. Compare: Local vs. Remote
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$CURRENT_BRANCH")

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
    if git diff --name-only HEAD.."origin/$CURRENT_BRANCH" | grep -q "^update.sh$"; then
        echo ""
        echo "⚡ Update script itself has an update!"
        echo ""
        echo "=== Changes in update.sh ==="
        git log --oneline --no-decorate HEAD.."origin/$CURRENT_BRANCH" -- update.sh
        echo ""
        git diff HEAD.."origin/$CURRENT_BRANCH" -- update.sh | head -30
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
        git checkout "origin/$CURRENT_BRANCH" -- update.sh
        chmod +x update.sh
        
        echo "✓ Update script updated. Restarting..."
        echo ""
        
        # Restart script with flags (pass stash info)
        exec bash "$REPO_DIR/update.sh" "--self-updated" "--stash-created=$STASH_CREATED"
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
git log --oneline --no-decorate HEAD.."origin/$CURRENT_BRANCH"

echo ""
echo "📂 Changed files:"
git diff --name-status HEAD.."origin/$CURRENT_BRANCH" | head -20

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
git pull origin "$CURRENT_BRANCH"

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