#!/usr/bin/env bash
# scripts/pull_and_run.sh
# Pull a minimal set of application files from a configured rclone remote and run a single-run cycle.
# - Avoids copying service-account keys and large residuals by default
# - Supports Docker build/run or local run (Python/Node)
#
# Usage examples:
# 1) Copy a Drive folder and run with Docker (preferred if Dockerfile present):
#    REMOTE=gdrive SOURCE_PATH=path/to/folder TARGET_DIR=./workspace ./scripts/pull_and_run.sh
# 2) Copy then run locally (Python/Node):
#    REMOTE=gdrive SOURCE_PATH=path/to/folder TARGET_DIR=./workspace RUN_MODE=local ./scripts/pull_and_run.sh
# 3) Only copy files (no run):
#    COPY_ONLY=true REMOTE=gdrive SOURCE_PATH=path/to/folder TARGET_DIR=./workspace ./scripts/pull_and_run.sh
#
# Environment variables:
#  REMOTE        - rclone remote name (default: gdrive)
#  SOURCE_PATH   - path inside the remote to copy (REQUIRED)
#  TARGET_DIR    - local directory to copy into (default: ./workspace)
#  INCLUDE       - optional additional include patterns (comma-separated)
#  EXCLUDE       - optional additional exclude patterns (comma-separated)
#  COPY_ONLY     - if true, only copy and do not attempt to run (default: false)
#  RUN_MODE      - 'docker'|'local'|'auto' (auto: prefer docker if Dockerfile present) (default: auto)
#  START_CMD     - override command used to start the app for local runs (default detected)
#  DOCKER_TAG    - docker image tag to build (default: murmur_app:latest)
#  PORT_MAP      - docker port mapping (default: 8080:8080)
#
set -euo pipefail

# Defaults
REMOTE=${REMOTE:-gdrive}
SOURCE_PATH=${SOURCE_PATH:-}
TARGET_DIR=${TARGET_DIR:-./workspace}
COPY_ONLY=${COPY_ONLY:-false}
RUN_MODE=${RUN_MODE:-auto}
START_CMD=${START_CMD:-}
DOCKER_TAG=${DOCKER_TAG:-murmur_app:latest}
PORT_MAP=${PORT_MAP:-8080:8080}

# Inclusion/exclusion defaults
# Include common app and deploy files; exclude secrets, service account jsons, large directories
DEFAULT_INCLUDES=("Dockerfile" "docker-compose.yml" "requirements.txt" "pyproject.toml" "Pipfile" "package.json" "package-lock.json" "src/**" "app.py" "main.py" "server.js" "index.js" "start.sh" "run.sh" "Procfile" "configs/**" "deploy/**" "scripts/**")
DEFAULT_EXCLUDES=("*.json" "*.key" "*.pem" "*.env" "node_modules/**" "__pycache__/**" ".git/**" "data/**" "datasets/**" "models/**" "*.tar.gz" "*.zip")

# Merge additional includes/excludes from ENV
IFS=',' read -r -a EXTRA_INCLUDES <<< "${INCLUDE:-}"
IFS=',' read -r -a EXTRA_EXCLUDES <<< "${EXCLUDE:-}"

INCLUDES=(${DEFAULT_INCLUDES[@]} ${EXTRA_INCLUDES[@]})
EXCLUDES=(${DEFAULT_EXCLUDES[@]} ${EXTRA_EXCLUDES[@]})

# Helper
die(){ echo "ERROR: $*" >&2; exit 1; }
run(){ echo "+ $*"; "$@"; }

if ! command -v rclone >/dev/null 2>&1; then
  die "rclone is required but not found. Install: https://rclone.org/install/"
fi

if [ -z "$SOURCE_PATH" ]; then
  die "SOURCE_PATH is required. Set SOURCE_PATH=path/to/folder inside the rclone remote."
fi

# Prepare target dir
mkdir -p "$TARGET_DIR"
TARGET_DIR=$(realpath "$TARGET_DIR")

# Build rclone include/exclude args. Use include rules to whitelist desired files (avoid copying whole drive)
RCLONE_ARGS=(copy "${REMOTE}:${SOURCE_PATH}" "$TARGET_DIR" --progress --create-empty-src-dirs)

# Add includes
for p in "${INCLUDES[@]}"; do
  # skip empty entries
  [ -z "$p" ] && continue
  RCLONE_ARGS+=(--include "$p")
done

# Add excludes
for p in "${EXCLUDES[@]}"; do
  [ -z "$p" ] && continue
  RCLONE_ARGS+=(--exclude "$p")
done

# Safety: always exclude common service-account file names
RCLONE_ARGS+=(--exclude "*service_account*.json" --exclude "*sa-*.json" --exclude "*credentials*.json")

# Optionally cap max size (avoid huge files). Set MAX_SIZE env to e.g. 500M
if [ -n "${MAX_SIZE:-}" ]; then
  RCLONE_ARGS+=(--max-size "$MAX_SIZE")
fi

# Print plan
echo "Pull plan:"
echo "  remote:    $REMOTE"
echo "  source:    $SOURCE_PATH"
echo "  target:    $TARGET_DIR"
echo "  copy-only: $COPY_ONLY"
echo "  run-mode:  $RUN_MODE"
echo "  includes:  ${INCLUDES[*]}"
echo "  excludes:  ${EXCLUDES[*]}"

# Execute rclone copy
echo "Starting rclone copy..."
run rclone "${RCLONE_ARGS[@]}"

echo "Copy complete. Inspecting $TARGET_DIR"

# If COPY_ONLY do not attempt to run
if [ "$COPY_ONLY" = "true" ]; then
  echo "COPY_ONLY=true, exiting after copy. Files are in: $TARGET_DIR"
  exit 0
fi

# Determine runtime files
HAS_DOCKERFILE=false
HAS_DOCKER_COMPOSE=false
HAS_REQUIREMENTS=false
HAS_PACKAGE_JSON=false
HAS_PY_ENTRY=false
HAS_NODE_ENTRY=false

[ -f "$TARGET_DIR/Dockerfile" ] && HAS_DOCKERFILE=true
[ -f "$TARGET_DIR/docker-compose.yml" ] && HAS_DOCKER_COMPOSE=true
[ -f "$TARGET_DIR/requirements.txt" ] && HAS_REQUIREMENTS=true
[ -f "$TARGET_DIR/package.json" ] && HAS_PACKAGE_JSON=true
[ -f "$TARGET_DIR/app.py" ] && HAS_PY_ENTRY=true
[ -f "$TARGET_DIR/main.py" ] && HAS_PY_ENTRY=true
[ -f "$TARGET_DIR/server.js" ] && HAS_NODE_ENTRY=true
[ -f "$TARGET_DIR/index.js" ] && HAS_NODE_ENTRY=true

echo "Detected: Dockerfile=$HAS_DOCKERFILE docker-compose=$HAS_DOCKER_COMPOSE requirements=$HAS_REQUIREMENTS package.json=$HAS_PACKAGE_JSON py_entry=$HAS_PY_ENTRY node_entry=$HAS_NODE_ENTRY"

# Decide run mode
if [ "$RUN_MODE" = "auto" ]; then
  if [ "$HAS_DOCKERFILE" = true ]; then
    USE_MODE="docker"
  elif [ "$HAS_PACKAGE_JSON" = true ] || [ "$HAS_REQUIREMENTS" = true ]; then
    USE_MODE="local"
  else
    USE_MODE="local"
  fi
else
  USE_MODE="$RUN_MODE"
fi

echo "Using run mode: $USE_MODE"

if [ "$USE_MODE" = "docker" ]; then
  if ! command -v docker >/dev/null 2>&1; then
    die "Docker not found; install docker or set RUN_MODE=local"
  fi
  # Build image
  echo "Building docker image $DOCKER_TAG from $TARGET_DIR"
  run docker build -t "$DOCKER_TAG" "$TARGET_DIR"

  # Stop existing container if present
  if docker ps -a --format '{{.Names}}' | grep -q '^murmur_run$'; then
    echo "Stopping and removing existing container 'murmur_run'"
    run docker rm -f murmur_run || true
  fi

  # Run container
  echo "Starting container 'murmur_run' mapping ports $PORT_MAP"
  run docker run -d --name murmur_run -p "$PORT_MAP" "$DOCKER_TAG"

  echo "Container started. Use 'docker logs -f murmur_run' to view logs."
  exit 0
fi

# Local run path (Python / Node)
cd "$TARGET_DIR"

if [ "$HAS_PACKAGE_JSON" = true ]; then
  if ! command -v npm >/dev/null 2>&1; then
    die "npm not found; install Node.js/npm or choose RUN_MODE=docker"
  fi
  echo "Installing npm dependencies..."
  run npm install --no-audit --no-fund
  # Determine start command
  if [ -n "$START_CMD" ]; then
    CMD_TO_RUN=(sh -c "$START_CMD")
  else
    # Try package.json scripts start
    if node -e "require('./package.json').scripts && process.exit(0)" 2>/dev/null; then
      CMD_TO_RUN=(npm start)
    else
      CMD_TO_RUN=(node index.js)
    fi
  fi
  echo "Starting (npm) with: ${CMD_TO_RUN[*]}"
  exec "${CMD_TO_RUN[@]}"
fi

if [ "$HAS_REQUIREMENTS" = true ] || [ "$HAS_PY_ENTRY" = true ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    die "python3 not found; install Python 3 or choose RUN_MODE=docker"
  fi
  # Create venv
  VENV_DIR="$TARGET_DIR/.venv"
  if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtualenv at $VENV_DIR"
    run python3 -m venv "$VENV_DIR"
  fi
  source "$VENV_DIR/bin/activate"
  if [ "$HAS_REQUIREMENTS" = true ]; then
    echo "Installing Python requirements..."
    pip install --upgrade pip
    run pip install -r requirements.txt
  fi

  # Decide start command
  if [ -n "$START_CMD" ]; then
    CMD_TO_RUN=(sh -c "$START_CMD")
  else
    if [ -f "$TARGET_DIR/app.py" ]; then
      CMD_TO_RUN=(python3 app.py)
    elif [ -f "$TARGET_DIR/main.py" ]; then
      CMD_TO_RUN=(python3 main.py)
    else
      die "No recognized Python entrypoint (app.py/main.py). Set START_CMD to override."
    fi
  fi
  echo "Starting (python) with: ${CMD_TO_RUN[*]}"
  exec "${CMD_TO_RUN[@]}"
fi

# Fallback: attempt to run start.sh if present
if [ -f "$TARGET_DIR/start.sh" ]; then
  echo "Found start.sh — making executable and running"
  chmod +x start.sh
  exec ./start.sh
fi

echo "No recognized run configuration found in $TARGET_DIR. Copy completed but no run started."
exit 0
