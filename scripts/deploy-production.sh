#!/usr/bin/env bash
set -euo pipefail

CI_ROOT="${CI_ROOT:-/opt/ci}"
DEPLOY_DIR="${DEPLOY_DIR:-$CI_ROOT/ci-deploy}"
SOURCE_COMPONENT="${SOURCE_COMPONENT:-all}"
SOURCE_SHA="${SOURCE_SHA:-}"
BACKEND_DIR="$CI_ROOT/ci-backend"
FRONTEND_DIR="$CI_ROOT/ci-frontend"

log() { printf '[ci-deploy] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

update_repo() {
  local directory="$1"
  local revision="${2:-}"

  [ -d "$directory/.git" ] || die "No es un repositorio Git: $directory"
  git -C "$directory" fetch --prune origin main

  if [ -n "$revision" ]; then
    git -C "$directory" fetch origin "$revision" || true
    git -C "$directory" cat-file -e "$revision^{commit}" 2>/dev/null \
      || die "El commit $revision no existe en $directory"
    git -C "$directory" reset --hard "$revision"
  else
    git -C "$directory" reset --hard origin/main
  fi
}

[ -f "$DEPLOY_DIR/.env" ] || die "Falta $DEPLOY_DIR/.env; crea uno desde .env.example"
[ -f "$DEPLOY_DIR/docker-compose.yml" ] || die "No existe docker-compose.yml"

case "$SOURCE_COMPONENT" in
  frontend)
    update_repo "$FRONTEND_DIR" "$SOURCE_SHA"
    cd "$DEPLOY_DIR"
    docker compose build frontend
    docker compose up -d --no-deps frontend
    ;;
  backend)
    update_repo "$BACKEND_DIR" "$SOURCE_SHA"
    cd "$DEPLOY_DIR"
    docker compose build gateway
    docker compose up -d --no-deps gateway auth academic students enrollment attendance-grades exams payments
    ;;
  deploy|all|"")
    update_repo "$DEPLOY_DIR" "$SOURCE_SHA"
    update_repo "$BACKEND_DIR"
    update_repo "$FRONTEND_DIR"
    cd "$DEPLOY_DIR"
    docker compose build gateway frontend
    docker compose up -d --remove-orphans
    ;;
  *)
    die "Componente no permitido: $SOURCE_COMPONENT"
    ;;
esac

cd "$DEPLOY_DIR"
if docker compose ps --services --filter "status=running" | grep -q "^gateway$"; then
  docker compose exec -T gateway node -e "fetch('http://127.0.0.1:3000/api/v1/health').then((response) => process.exit(response.ok ? 0 : 1)).catch(() => process.exit(1))"
fi
log "Despliegue de $SOURCE_COMPONENT completado"
