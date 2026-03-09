# mailcow Backup Script v3.0.0 - Major Release (English)

I am happy to announce **mailcow Backup Script v3.0.0**.
This major release introduces internationalization, new upload targets, and a safer update workflow.

## Highlights

- Internationalized scripts and outputs for better collaboration
- Bilingual documentation (German and English)
- New upload methods: NAS and S3-compatible providers
- Two-phase update flow with self-update first, then full repository update
- Automatic systemd service path repair after updates
- Better dependency validation with optional install flow

## Notable Changes

### New Features

- NAS upload support for mounted SMB/CIFS and NFS paths
- S3 upload support via AWS CLI (AWS S3 and S3-compatible services)
- Branch-aware update behavior with clear stable/development tracks
- Status-flag workflow to avoid uploads before backup completion

### Improvements

- Better retention handling and timestamped backup naming
- More robust error handling across backup and upload scripts
- Setup workflow now covers all upload methods

### Breaking Changes

- Script outputs are now standardized in English
- Backup naming format updated to `mailcow-backup_YYYY-MM-DD_HH-MM-SS.tar.gz`
- Backup script moved to `Backup/mailcow-backup.sh`

## Upgrade from V2 to V3

Important note: the original V2 branch did not include an `update.sh`.
For old V2 installations, a bootstrap step is required before branch switching with flags is possible.

After that, `git pull` normally fetches new files as well, so manual copying is usually no longer required.

One-time bootstrap for V2 installations without `update.sh`:

```bash
cd /root/mailcow-backup
curl -fsSL https://raw.githubusercontent.com/the1andoni/mailcow-backup/V2-LEGACY/update.sh -o update.sh
chmod +x update.sh
sudo ./update.sh --v3
```

Alternative (cleanest path): clone fresh and migrate your configuration:

```bash
git clone -b V3 https://github.com/the1andoni/mailcow-backup.git mailcow-backup-v3
cd mailcow-backup-v3
```

## Supported Upload Targets

- WebDAV (for example Nextcloud, ownCloud, HiDrive)
- FTP/SFTP
- NAS (mounted SMB/CIFS or NFS)
- S3-compatible providers (AWS S3, Wasabi, MinIO, Backblaze B2, and others)

## Release Assets

- Debian package: `mailcow-backup_3.0.0_all.deb`
- Source via Git tags and branches

## Links

- Release Notes: `RELEASE_NOTES_V3.md`
- Stable branch: <https://github.com/the1andoni/mailcow-backup/tree/V3>
- Releases: <https://github.com/the1andoni/mailcow-backup/releases>

## Thank You

Thanks to everyone who shared feedback and helped improve the project.
