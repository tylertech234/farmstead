#!/usr/bin/env bash
set -euo pipefail

# pull-model.sh — pull the Ollama model specified in .env
#
# Usage:  bash scripts/pull-model.sh [model_name]
# If no model name is given, reads OLLAMA_MODEL from .env

ENV_FILE="$(cd "$(dirname "$0")/.." && pwd)/.env"

if [ -n "${1:-}" ]; then
  MODEL="$1"
elif [ -f "$ENV_FILE" ]; then
  MODEL=$(grep -E '^OLLAMA_MODEL=' "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
fi

if [ -z "${MODEL:-}" ]; then
  echo "ERROR: No model specified and OLLAMA_MODEL not found in .env"
  echo "Usage: $0 [model_name]"
  exit 1
fi

echo "Pulling model: $MODEL"
docker exec -it ollama ollama pull "$MODEL"
echo "Done. Model $MODEL is ready."
