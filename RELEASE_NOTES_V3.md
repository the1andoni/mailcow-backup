# Release Notes - mailcow-backup V3.x

## Version 3.1.0 (Upcoming)

### 🎯 New Features

- **Branch-Aware Update Script**: `update.sh` now automatically detects and updates from the current branch
  - Prevents accidental branch switches during updates
  - Shows branch-specific warnings (development/stable/legacy)
  - V2-LEGACY users stay on V2-LEGACY track
  - V3 users stay on stable track
  - main branch users see development warning

- **Manual Version/Branch Flags in `update.sh`**
  - New flags: `--main`, `--v3`, `--v2`
  - Supported shortcuts: `main`, `V3`/`v3`, `V2`/`v2`
  - Explicit upgrade path enforcement: `V2-LEGACY -> V3 -> main`
  - Downgrades are blocked (for example `main -> V3` or `V3 -> V2-LEGACY`)
  - `--help` now includes version flag usage and upgrade/downgrade rules

Example usage:

```bash
./update.sh --v3
./update.sh --main
./update.sh --v2
```

### 📚 Documentation

- **V2 to V3 Migration Guide**: Added comprehensive migration instructions to V2-LEGACY README
  - Step-by-step migration process
  - Configuration backup and migration steps
  - Breaking changes documentation
  - Available in English and German

### 🔧 Improvements

- Better user experience: Users on different branches receive appropriate guidance
- Clear separation between stable (V3) and development (main) tracks

---

## Version 3.0.0

### 🎯 New Features

- **Improved mailcow Integration**: Direct use of mailcow's official backup helper script
  - More reliable backups using `./helper-scripts/backup_and_restore.sh`
  - Better integration with mailcow's native backup functionality
  - Respects mailcow's retention policies

- **Internationalization Foundation**:
  - Scripts, outputs, and comments standardized to English
  - Improved maintainability for international contributors

- **Enhanced Dependency Management**:
  - Optional dependency support with `optional:package-name` syntax
  - AWS CLI fallback installer when apt package unavailable
  - Automatic detection of system architecture (x86_64/aarch64)
  - Graceful handling of missing optional dependencies

- **New Upload Targets in V3**:
  - Added NAS upload workflow for mounted shares (SMB/CIFS, NFS)
  - Added S3 upload workflow for AWS S3 and S3-compatible providers

- **Systemd Service Repair**: Automatic path correction after repository moves or updates
  - Repairs ExecStart paths in systemd unit files
  - Prevents broken timer/service configurations

### 🔧 Improvements

- **Backup Script**:
  - Uses relative path for mailcow helper script (more portable)
  - Better error handling for missing mailcow installation
  - Improved validation of mailcow directory structure
  - Timestamped archive naming for clearer backup history

- **Dependency Installer**:
  - Three-tier AWS CLI installation fallback:
    1. Try `apt install awscli`
    2. Try `apt install aws-cli`
    3. Install official AWS CLI v2 from Amazon (with unzip dependency check)
  - Better error messages and installation guidance
  - Optional dependencies don't block installation

### 📋 Dependencies Updates

- **AWS CLI**: Now optional dependency with intelligent fallback installation
- **Core dependencies**: gpg, curl, tar, cron (required)
- **Upload-specific**: awscli (S3), curl (WebDAV/FTP/SFTP), mountpoint (NAS)

### 🔄 Breaking Changes

1. **Mailcow Helper Script Requirement**:
   - Backup now requires mailcow's helper script at `./helper-scripts/backup_and_restore.sh`
   - Script must be called from mailcow-dockerized directory
   - Migration: Ensure your mailcow installation includes the helper script (standard in recent versions)

2. **AWS CLI Installation**:
   - Changed from hard dependency to optional with fallback
   - Uses official AWS CLI v2 installer if apt package unavailable
   - Migration: Existing installations unaffected, new installations benefit from improved installer

### 🐛 Bug Fixes

- Fixed hardcoded repository name references (mailcow-backupV2 → mailcow-backup)
- Fixed backup script to use correct relative path for mailcow helper
- Fixed AWS CLI installation failures on systems without apt package
- Improved robustness of upload pre-checks and error handling

### 📚 Documentation

- Updated branch strategy documentation across all branches
- Added branch information to README (main/V3/V2-LEGACY)
- Improved clone instructions with branch-specific guidance
- Added migration guide for V2 to V3 upgrades

### 🔐 Security

- No security-specific changes in this release
- Existing GPG encryption (AES256) for configuration files maintained

### ⚠️ Migration from V2

**Important**: V2-LEGACY branch update.sh will keep you on V2-LEGACY. Manual migration required.

#### Quick Migration Steps:

1. Backup your configuration:
   ```bash
   cp -r Configs Configs.backup
   sudo cp /root/.mailcow-gpg-pass /root/.mailcow-gpg-pass.backup
   ```

2. Clone V3:
   ```bash
   git clone -b V3 https://github.com/the1andoni/mailcow-backup.git mailcow-backup-v3
   cd mailcow-backup-v3
   ```

3. Copy configs and run setup:
   ```bash
   cp ../mailcow-backup/Configs/* Configs/
   sudo ./setup.sh
   ```

4. Test backup:
   ```bash
   sudo bash Backup/mailcow-backup.sh
   ```

For detailed migration instructions, see the [V2-LEGACY README](https://github.com/the1andoni/mailcow-backup/tree/V2-LEGACY#-migrating-from-v2-to-v3).

### 📦 Distribution

- Debian package available: `mailcow-backup_3.0.0_all.deb` (19KB)
- Source installation via Git clone (recommended)

### 🙏 Contributors

- [@the1andoni](https://github.com/the1andoni) - Project maintainer

### 📊 Stats

- Lines changed: ~500+ across multiple files
- Files modified: 10+
- Branches: main (development), V3 (stable), V2-LEGACY (legacy support)

---

## Branch Strategy

Starting with V3, the project uses a three-branch strategy:

| Branch | Purpose | Status | Recommended For |
|--------|---------|--------|-----------------|
| `main` | Active development | ⚠️ Unstable | Development/testing only |
| `V3` | Stable v3.x releases | ✅ Stable | **Production use** |
| `V2-LEGACY` | Legacy v2.x support | ⚠️ Legacy | Existing v2 installations only |

### Update Behavior by Branch

- **main**: Updates from `origin/main` (latest development code)
- **V3**: Updates from `origin/V3` (stable releases only)
- **V2-LEGACY**: Updates from `origin/V2-LEGACY` (critical fixes only)

### Optional Explicit Branch Switch via Flag

- `./update.sh --main` switches to `main` and updates
- `./update.sh --v3` switches to `V3` and updates
- `./update.sh --v2` switches to `V2-LEGACY` and updates
- Downgrades are intentionally blocked to reduce accidental regressions

The update script is now branch-aware and will not accidentally switch your installation to a different track.

---

## Support

- **Issues**: [GitHub Issues](https://github.com/the1andoni/mailcow-backup/issues)
- **Discussions**: [GitHub Discussions](https://github.com/the1andoni/mailcow-backup/discussions)
- **Documentation**: [README.md](https://github.com/the1andoni/mailcow-backup/blob/V3/README.md)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
