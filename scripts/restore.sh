#!/usr/bin/env bash
set -euo pipefail

# restore.sh — restore a single Docker volume from a tar.gz archive
#
# Usage:  bash scripts/restore.sh <archive.tar.gz> <volume_name>
# Example: bash scripts/restore.sh backups/2024-03-15/n8n_data.tar.gz farmstead_n8n_data
#
# WARNING: This will overwrite all data in the target volume.

if [ $# -lt 2 ]; then
  echo "Usage: $0 <archive.tar.gz> <volume_name>"
  echo ""
  echo "Example:"
  echo "  $0 backups/2024-03-15/n8n_data.tar.gz farmstead_n8n_data"
  echo ""
  echo "Available volumes:"
  docker volume ls --format '  {{.Name}}' || echo "  (none found)"
  exit 1
fi

ARCHIVE="$1"
VOLUME="$2"

if [ ! -f "$ARCHIVE" ]; then
  echo "ERROR: Archive not found: $ARCHIVE"
  exit 1
fi

if ! docker volume inspect "$VOLUME" &>/dev/null; then
  echo "Volume $VOLUME does not exist. Creating it..."
  docker volume create "$VOLUME"
fi

ARCHIVE_ABS="$(cd "$(dirname "$ARCHIVE")" && pwd)/$(basename "$ARCHIVE")"

echo "Restoring $ARCHIVE → $VOLUME ..."
echo "WARNING: This will overwrite existing data in the volume."
read -rp "Continue? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

docker run --rm \
  -v "$VOLUME":/data \
  -v "$ARCHIVE_ABS":/backup/archive.tar.gz:ro \
  alpine sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null; tar xzf /backup/archive.tar.gz -C /data"

echo "Done. Volume $VOLUME restored from $ARCHIVE"
