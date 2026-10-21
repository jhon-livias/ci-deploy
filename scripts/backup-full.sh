#!/usr/bin/env bash
# Backup completo (PostgreSQL + MinIO) con retención. RETENTION_DAYS=14 por defecto.
# Cron sugerido: 30 2 * * * /opt/ci/ci-deploy/scripts/backup-full.sh
set -euo pipefail
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${BACKUP_BASE:-$DEPLOY_DIR/backups}"
DEST="$BASE/$(date +%F_%H%M%S)"
mkdir -p "$DEST"
bash "$DEPLOY_DIR/scripts/backup-postgres.sh" "$DEST"
bash "$DEPLOY_DIR/scripts/backup-storage.sh" "$DEST"
find "$DEST" -type f -exec sha256sum {} + > "$DEST/SHA256SUMS"
find "$BASE" -mindepth 1 -maxdepth 1 -type d -mtime +"${RETENTION_DAYS:-14}" -exec rm -rf {} +
echo "[backup-full] OK: $DEST"