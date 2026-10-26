#!/usr/bin/env bash
set -euo pipefail

CI_ROOT="${CI_ROOT:-/opt/ci}"
DEPLOY_DIR="${DEPLOY_DIR:-$CI_ROOT/ci-deploy}"
SOURCE_COMPONENT="${SOURCE_COMPONENT:-all}"
SOURCE_SHA="${SOURCE_SHA:-}"
BACKEND_DIR="$CI_ROOT/ci-backend"
FRONTEND_DIR="$CI_ROOT/ci-frontend"
DEPLOY_STATE_FILE="${DEPLOY_STATE_FILE:-$CI_ROOT/.ci-deploy-state}"
SAVE_DEPLOYMENT_STATE=false

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

deployment_state() {
  printf 'deploy=%s\nbackend=%s\nfrontend=%s\n' \
    "$(git -C "$DEPLOY_DIR" rev-parse HEAD)" \
    "$(git -C "$BACKEND_DIR" rev-parse HEAD)" \
    "$(git -C "$FRONTEND_DIR" rev-parse HEAD)"
}

save_deployment_state() {
  local temporary_file="${DEPLOY_STATE_FILE}.tmp.$$"
  deployment_state > "$temporary_file"
  mv "$temporary_file" "$DEPLOY_STATE_FILE"
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
    docker compose build gateway auth-migrate academic-migrate
    docker compose run --rm auth-migrate
    docker compose run --rm academic-migrate
    docker compose up -d --no-deps gateway auth academic students enrollment attendance-grades exams payments
    ;;
  deploy|all|"")
    update_repo "$DEPLOY_DIR" "$SOURCE_SHA"
    update_repo "$BACKEND_DIR"
    update_repo "$FRONTEND_DIR"
    if [ -f "$DEPLOY_STATE_FILE" ] && cmp -s "$DEPLOY_STATE_FILE" <(deployment_state); then
      log "Los commits actuales ya están desplegados; se omite el CD duplicado"
      exit 0
    fi
    cd "$DEPLOY_DIR"
    docker compose build gateway frontend auth-migrate academic-migrate
    docker compose run --rm auth-migrate
    docker compose run --rm academic-migrate
    # Wait until dependency-gated services such as reverse-proxy have actually
    # started. Without --wait Compose can return while a service remains only
    # in the Created state after its dependencies become healthy.
    docker compose up -d --remove-orphans --wait --wait-timeout 180
    # Git updates bind-mounted Nginx files by replacing their inode. Recreate
    # only the proxy so it mounts the updated configuration without restarting
    # the application or data services.
    docker compose up -d --no-deps --force-recreate reverse-proxy
    docker compose up -d --wait --wait-timeout 180 reverse-proxy
    SAVE_DEPLOYMENT_STATE=true
    ;;
  *)
    die "Componente no permitido: $SOURCE_COMPONENT"
    ;;
esac

cd "$DEPLOY_DIR"
if docker compose ps --services --filter "status=running" | grep -q "^gateway$"; then
  docker compose exec -T gateway node -e "fetch('http://127.0.0.1:3000/api/v1/health').then((response) => process.exit(response.ok ? 0 : 1)).catch(() => process.exit(1))"
fi
[ "$SAVE_DEPLOYMENT_STATE" = true ] && save_deployment_state
log "Despliegue de $SOURCE_COMPONENT completado"
