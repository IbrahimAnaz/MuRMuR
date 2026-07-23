# Run-cycle helper

This script pulls a minimal set of files from a configured rclone remote and performs a run cycle (build/run) using Docker or local runtime.

Files:
- scripts/pull_and_run.sh -- main script to copy and run

Notes:
- The script intentionally excludes *.json, *.env, and common large directories to avoid copying service-account keys or big datasets. If you need to include a particular file, pass INCLUDE env var (comma-separated patterns) but be careful not to include secrets.
- Example:
  REMOTE=gdrive SOURCE_PATH=MyProject TARGET_DIR=./workspace ./scripts/pull_and_run.sh

