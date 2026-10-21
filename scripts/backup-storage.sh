#!/usr/bin/env bash
# Copia del volumen de MinIO. Uso: ./scripts/backup-storage.sh [directorio_destino]
set -euo pipefail
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-$DEPLOY_DIR/backups/$(date +%F_%H%M%S)}"
PROJECT="${COMPOSE_PROJECT_NAME:-ci}"
mkdir -p "$DEST/storage"
docker run --rm -v "${PROJECT}_minio-data:/data:ro" -v "$DEST/storage:/backup" alpine \
  tar -czf /backup/minio.tar.gz -C /data .
echo "[backup-storage] $DEST/storage/minio.tar.gz"