#!/usr/bin/env bash
# Libera disco tras builds. NO usa "volume prune": los datos viven en volúmenes con nombre.
# Uso: ./scripts/docker-cleanup.sh [--pre]
set -euo pipefail
MODE="${1:-post}"
echo "[docker-cleanup] antes:"; docker system df
docker builder prune -af >/dev/null 2>&1 || true
if [ "$MODE" != "--pre" ]; then
  docker image prune -af >/dev/null 2>&1 || true
  docker container prune -f >/dev/null 2>&1 || true
  docker network prune -f >/dev/null 2>&1 || true
fi
echo "[docker-cleanup] después:"; docker system df