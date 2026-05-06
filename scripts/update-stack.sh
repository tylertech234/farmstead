#!/usr/bin/env bash
# update-stack.sh — Pull latest images, recreate containers, and prune old images
#
# Usage:
#   bash scripts/update-stack.sh              # Update using CPU compose only
#   bash scripts/update-stack.sh --gpu        # Update with GPU overlay
#   bash scripts/update-stack.sh --dry-run    # Show what would be pulled without applying
set -euo pipefail
cd "$(dirname "$0")/.."

# ── Parse flags ───────────────────────────────────────────────────────────────
GPU=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --gpu)    GPU=true ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: bash scripts/update-stack.sh [--gpu] [--dry-run]"
      echo "  --gpu      Include docker-compose.gpu.yml overlay (NVIDIA GPU)"
      echo "  --dry-run  Show images that would be pulled without making changes"
      exit 0
      ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

# ── Build compose command ─────────────────────────────────────────────────────
COMPOSE="docker compose -f docker-compose.yml"
if $GPU; then
  COMPOSE="$COMPOSE -f docker-compose.gpu.yml"
fi

echo "═══════════════════════════════════════════════════════════"
echo "  Farmstead Update"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── Step 1: Pull latest images ───────────────────────────────────────────────
echo "▶ Pulling latest images..."
if $DRY_RUN; then
  echo "  (dry-run) Would run: $COMPOSE pull"
  $COMPOSE config --images | sort | while read -r img; do
    echo "  - $img"
  done
  echo ""
  echo "Dry run complete. No changes made."
  exit 0
fi

$COMPOSE pull
echo ""

# ── Step 2: Recreate containers with new images ─────────────────────────────
echo "▶ Recreating containers..."
$COMPOSE up -d
echo ""

# ── Step 3: Wait for health checks ──────────────────────────────────────────
echo "▶ Waiting for containers to become healthy..."
sleep 10
$COMPOSE ps
echo ""

# ── Step 4: Prune old images ────────────────────────────────────────────────
echo "▶ Pruning unused images..."
docker image prune -f
echo ""

# ── Done ─────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════"
echo "  Update complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Run 'docker compose ps' to verify all services are healthy."
