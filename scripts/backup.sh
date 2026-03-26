#!/usr/bin/env bash
set -euo pipefail

# backup.sh — dump all named Docker volumes to dated tar.gz archives
#
# Usage:  bash scripts/backup.sh
# Output: backups/YYYY-MM-DD/<volume>.tar.gz

BACKUP_ROOT="$(cd "$(dirname "$0")/.." && pwd)/backups"
DATE_DIR="$BACKUP_ROOT/$(date +%Y-%m-%d)"
COMPOSE_FILE="$(cd "$(dirname "$0")/.." && pwd)/docker-compose.yml"

# Extract volume names from docker-compose.yml (top-level volumes section)
VOLUMES=$(docker compose -f "$COMPOSE_FILE" config --volumes 2>/dev/null)

if [ -z "$VOLUMES" ]; then
  echo "ERROR: No volumes found in docker-compose.yml"
  exit 1
fi

mkdir -p "$DATE_DIR"

PROJECT=$(basename "$(cd "$(dirname "$0")/.." && pwd)")

echo "Backing up volumes to $DATE_DIR ..."
echo ""

for VOL in $VOLUMES; do
  FULL_VOL="${PROJECT}_${VOL}"

  # Check if the volume exists
  if ! docker volume inspect "$FULL_VOL" &>/dev/null; then
    echo "  SKIP  $FULL_VOL (does not exist)"
    continue
  fi

  ARCHIVE="$DATE_DIR/${VOL}.tar.gz"
  echo "  DUMP  $FULL_VOL → $ARCHIVE"
  docker run --rm \
    -v "$FULL_VOL":/data:ro \
    -v "$DATE_DIR":/backup \
    alpine tar czf "/backup/${VOL}.tar.gz" -C /data .
done

echo ""
echo "Done. Backups saved to $DATE_DIR"
