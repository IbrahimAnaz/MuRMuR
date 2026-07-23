#!/usr/bin/env bash
# scripts/mount-gdrive.sh
# Simple helper to mount a Google Drive remote using rclone.
# Usage:
#   ./scripts/mount-gdrive.sh                 # interactive remote name: gdrive, mount: /mnt/gdrive
#   REMOTE=other ./scripts/mount-gdrive.sh    # use a different rclone remote
#   FOLDER_ID=abcdef12345 ./scripts/mount-gdrive.sh   # mount only a subfolder by ID (recommended)
#   SA_JSON=/path/to/sa.json ./scripts/mount-gdrive.sh # use service account json (do NOT commit credentials)

set -euo pipefail

# Defaults (override via env)
REMOTE=${REMOTE:-gdrive}
MOUNT_POINT=${MOUNT_POINT:-/mnt/gdrive}
FOLDER_ID=${FOLDER_ID:-}
SA_JSON=${SA_JSON:-}
READ_ONLY=${READ_ONLY:-false}
VFS_CACHE_MAX_SIZE=${VFS_CACHE_MAX_SIZE:-1G}
BUFFER_SIZE=${BUFFER_SIZE:-32M}
DIR_CACHE_TIME=${DIR_CACHE_TIME:-72h}
POLL_INTERVAL=${POLL_INTERVAL:-15s}
ALLOW_OTHER=${ALLOW_OTHER:-true}
LOG_LEVEL=${LOG_LEVEL:-INFO}

# Helper: print and run
run() { echo "+ $*"; "$@"; }

# Ensure rclone installed
if ! command -v rclone >/dev/null 2>&1; then
  echo "rclone not found. Install rclone first: https://rclone.org/install/"
  exit 2
fi

# Create mount point
if [ ! -d "$MOUNT_POINT" ]; then
  echo "Creating mount point $MOUNT_POINT"
  run sudo mkdir -p "$MOUNT_POINT" || mkdir -p "$MOUNT_POINT"
  run sudo chown "$USER":"$USER" "$MOUNT_POINT" || true
fi

# If service account JSON provided, create a tmp config override (avoid committing creds)
TEMP_CONFIG=""
if [ -n "$SA_JSON" ]; then
  if [ ! -f "$SA_JSON" ]; then
    echo "Service account JSON not found at $SA_JSON" >&2
    exit 2
  fi
  echo "Using service account JSON from $SA_JSON"
  # Use RCLONE_CONFIG environment to point to a temporary config that references the SA.
  TEMP_CONFIG="/tmp/rclone-service-account.conf"
  cat > "$TEMP_CONFIG" <<EOF
[gdrive]
type = drive
service_account_file = $SA_JSON
scope = drive
EOF
  export RCLONE_CONFIG="$TEMP_CONFIG"
fi

# Build remote target (optionally limit to a folder id)
TARGET="${REMOTE}:"
if [ -n "$FOLDER_ID" ]; then
  TARGET="${REMOTE}:${FOLDER_ID}"
  echo "Mounting only folder ID: $FOLDER_ID (set FOLDER_ID to empty to mount root)"
fi

# Build mount command
ARGS=(mount "$TARGET" "$MOUNT_POINT")
if [ "$ALLOW_OTHER" = "true" ]; then
  ARGS+=(--allow-other)
fi
ARGS+=(--vfs-cache-mode full)
ARGS+=(--vfs-cache-max-size "$VFS_CACHE_MAX_SIZE")
ARGS+=(--buffer-size "$BUFFER_SIZE")
ARGS+=(--dir-cache-time "$DIR_CACHE_TIME")
ARGS+=(--poll-interval "$POLL_INTERVAL")
ARGS+=(--log-level "$LOG_LEVEL")

if [ "$READ_ONLY" = "true" ]; then
  ARGS+=(--read-only)
fi

# Run the mount command in background
echo "Running: rclone ${ARGS[*]}"
# Use setsid to detach; user can stop with 'fusermount -u' or 'umount'
setsid rclone "${ARGS[@]}" &
PID=$!

echo "rclone mount started (pid=$PID). Mounted at: $MOUNT_POINT"

echo "Tip: to unmount: fusermount -u $MOUNT_POINT  (or: umount $MOUNT_POINT)"

# Cleanup temp config on exit
if [ -n "$TEMP_CONFIG" ]; then
  trap 'rm -f "$TEMP_CONFIG"' EXIT
fi
