#!/usr/bin/env bash
# Restaura un backup. DESTRUCTIVO: sobrescribe la base y el volumen de MinIO.
# Uso: RESTORE_CONFIRM=yes ./scripts/restore-full.sh /ruta/backups/2026-01-01_023000
set -euo pipefail
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${1:-}"
PROJECT="${COMPOSE_PROJECT_NAME:-ci}"
[ -d "$BACKUP_DIR" ] || { echo "Indica un directorio de backup válido" >&2; exit 1; }
[ "${RESTORE_CONFIRM:-}" = "yes" ] || { echo "Operación destructiva: exporta RESTORE_CONFIRM=yes" >&2; exit 1; }
cd "$DEPLOY_DIR"
(cd "$BACKUP_DIR" && sha256sum -c SHA256SUMS)
docker compose up -d postgres minio
docker compose stop gateway auth academic students enrollment attendance-grades exams payments frontend reverse-proxy || true
gunzip -c "$BACKUP_DIR/database/postgres.sql.gz" \
  | docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q'
if [ -f "$BACKUP_DIR/storage/minio.tar.gz" ]; then
  docker compose stop minio
  docker run --rm -v "${PROJECT}_minio-data:/data" -v "$BACKUP_DIR/storage:/backup:ro" alpine \
    sh -c 'rm -rf /data/* /data/.[!.]* 2>/dev/null; tar -xzf /backup/minio.tar.gz -C /data'
fi
docker compose up -d
echo "[restore-full] Restauración completada desde $BACKUP_DIR"