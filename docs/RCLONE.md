# RCLONE: Mounting Google Drive for development and deploy

This document explains how to mount a Google Drive remote using rclone, how to mount only a subfolder, service account usage, and how to auto-mount with systemd.

WARNING: Never commit service account JSON files, OAuth tokens, or .env secrets into this repo.

## Quick: install rclone
- Linux (Debian/Ubuntu):
  curl https://rclone.org/install.sh | sudo bash
- macOS: brew install rclone
- Windows: use the rclone installer or scoop

## Quick interactive setup
1. Run `rclone config` and create a remote named `gdrive` (or pick another name).
2. Test: `rclone lsf gdrive:`

## Service account (non-interactive / server)
1. Create a Google Cloud project, enable Drive API, create a Service Account, and download the JSON key.
2. Share the Drive folder (or files) with the service account email if using a personal Drive.
3. Create a remote referencing the JSON (on the host):
   rclone config create gdrive drive service_account_file=/path/to/sa.json scope=drive

To restrict the remote root to a single folder ID (recommended for large drives):
   rclone config create gdrive drive service_account_file=/path/to/sa.json scope=drive drive-root-folder-id=FOLDER_ID

## Mounting (recommended: mount only the needed folder)
- Create mount point and mount:

  sudo mkdir -p /mnt/gdrive
  sudo chown $USER:$USER /mnt/gdrive

  # Mount root (not recommended for very large drives)
  rclone mount gdrive: /mnt/gdrive --allow-other --vfs-cache-mode full --vfs-cache-max-size 1G &

  # Mount a specific folder by ID (preferred):
  rclone mount gdrive:FOLDER_ID /mnt/gdrive --allow-other --vfs-cache-mode full --vfs-cache-max-size 1G &

Notes on flags:
- --vfs-cache-mode full: best for apps needing stable file handles (editors, installers). Uses disk space.
- --vfs-cache-max-size: limit disk cache usage (tune to system RAM/disk). Default used in this repo: 1G.
- --allow-other: allows other users on the system to see the mount (requires /etc/fuse.conf to allow it).

## Auto-mount with systemd
- Copy `systemd/rclone-gdrive.service` to `/etc/systemd/system/rclone-gdrive.service` and edit Environment variables there (especially REMOTE, MOUNT_POINT, and FOLDER_ID).

  sudo cp systemd/rclone-gdrive.service /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl enable --now rclone-gdrive
  sudo journalctl -u rclone-gdrive -f

## Alternatives: copy only needed files (recommended for reliability)
If your app needs only a small subset of files (deploy scripts, Dockerfile, app sources), prefer copying rather than mounting:

  # copy a folder or pattern
  rclone copy gdrive:path/to/subfolder /local/path --progress --include "deploy/**" --include "app*/**"

This is more reliable for CI and build systems.

## Example usage in CI
- Don't store SA JSON in repo. Store it as a secret and write it to a file at runtime (chmod 600) and set RCLONE_CONFIG or use `rclone config create` dynamically.

## Security
- Keep service account JSON files out of the repository.
- Use minimal scopes for the service account.
- Use read-only mounts if you don't need to write.

