#!/usr/bin/env bash
set -euo pipefail

CI_ROOT="${CI_ROOT:-/opt/ci}"
DEPLOY_DIR="${DEPLOY_DIR:-$CI_ROOT/ci-deploy}"
SOURCE_COMPONENT="${SOURCE_COMPONENT:-all}"
SOURCE_SHA="${SOURCE_SHA:-}"
BACKEND_DIR="$CI_ROOT/ci-backend"
FRONTEND_DIR="$CI_ROOT/ci-language-center"
TICKETS_FRONTEND_DIR="$CI_ROOT/ci-tickets"
IDENTITY_FRONTEND_DIR="$CI_ROOT/ci-identity"
STUDY_PLANS_FRONTEND_DIR="$CI_ROOT/ci-study-plans"
STUDY_PLANS_FRONTEND_URL="${STUDY_PLANS_FRONTEND_URL:-https://github.com/jhon-livias/ci-study-plans.git}"
DEPLOY_STATE_FILE="${DEPLOY_STATE_FILE:-$CI_ROOT/.ci-deploy-state}"
SAVE_DEPLOYMENT_STATE=false

log() { printf '[ci-deploy] %s\n' "$*" >&2; }
trap '' PIPE
trap 'log "se detuvo en la linea $LINENO"' ERR
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

ensure_checkout() {
  local directory="$1"
  local url="$2"
  if [ ! -d "$directory/.git" ]; then
    log "Clonando el repositorio de planes de estudio"
    git clone --branch main "$url" "$directory"
  fi
  update_repo "$directory"
}

deployment_state() {
  printf 'deploy=%s\nbackend=%s\nfrontend=%s\ntickets_frontend=%s\nidentity_frontend=%s\nstudy_plans_frontend=%s\n' \
    "$(git -C "$DEPLOY_DIR" rev-parse HEAD)" \
    "$(git -C "$BACKEND_DIR" rev-parse HEAD)" \
    "$(git -C "$FRONTEND_DIR" rev-parse HEAD)" \
    "$(git -C "$TICKETS_FRONTEND_DIR" rev-parse HEAD)" \
    "$(git -C "$IDENTITY_FRONTEND_DIR" rev-parse HEAD)" \
    "$(git -C "$STUDY_PLANS_FRONTEND_DIR" rev-parse HEAD)"
}

ensure_secret() {
  local key="$1"
  local min="$2"
  local current
  current="$(grep -a "^${key}=" .env | tail -n 1 | cut -d= -f2- || true)"
  if [ "${#current}" -ge "$min" ]; then
    return 0
  fi
  local value
  value="$(openssl rand -hex 20)"
  local tmp
  tmp="$(mktemp)"
  grep -a -v "^${key}=" .env > "$tmp" || true
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" .env
  chmod 600 .env
  log "Se creó $key porque no estaba definido"
}

ensure_csv() {
  local key="$1"
  local item="$2"
  local current tmp
  current="$(grep -a "^${key}=" .env | tail -n 1 | cut -d= -f2- || true)"
  case ",$current," in
    *,"$item",*) return 0 ;;
  esac
  tmp="$(mktemp)"
  grep -a -v "^${key}=" .env > "$tmp" || true
  printf '%s=%s\n' "$key" "${current:+$current,}$item" >> "$tmp"
  mv "$tmp" .env
  chmod 600 .env
}

prepare_env() {
  cd "$DEPLOY_DIR"
  ensure_secret AUTH_DB_PASSWORD 16
  ensure_secret ACADEMIC_DB_PASSWORD 16
  ensure_secret STUDENTS_DB_PASSWORD 16
  ensure_secret ENROLLMENT_DB_PASSWORD 16
  ensure_secret ATTENDANCE_DB_PASSWORD 16
  ensure_secret PAYMENTS_DB_PASSWORD 16
  ensure_secret TICKETS_DB_PASSWORD 16
  ensure_secret STUDY_PLANS_DB_PASSWORD 16
  ensure_secret ACADEMIC_INTERNAL_SECRET 32
  ensure_secret STUDENTS_INTERNAL_SECRET 32
  ensure_secret ENROLLMENT_INTERNAL_SECRET 32
  ensure_secret ATTENDANCE_INTERNAL_SECRET 32
  ensure_secret PAYMENTS_INTERNAL_SECRET 32
  ensure_csv APP_ALLOWED_ORIGINS "https://planes.uprit.edu.pe"
  ensure_csv RECAPTCHA_ALLOWED_HOSTNAMES "planes.uprit.edu.pe"
}

backup_database() {
  cd "$DEPLOY_DIR"
  if docker compose ps --services --filter "status=running" | grep -q '^postgres$'; then
    log "Copia de PostgreSQL antes de migrar"
    bash scripts/backup-postgres.sh "$DEPLOY_DIR/backups/pre-deploy-$(date +%F_%H%M%S)"
  else
    log "Postgres no está en marcha; no hay una base previa que copiar"
  fi
}

release_backend() {
  cd "$DEPLOY_DIR"
  docker compose build gateway auth-migrate academic-migrate payments-migrate attendance-grades-migrate students-migrate enrollment-migrate tickets-migrate study-plans-migrate
  docker compose run --rm auth-migrate
  docker compose --profile manual run --rm auth-tickets-bootstrap
  docker compose run --rm academic-migrate
  docker compose run --rm payments-migrate
  docker compose run --rm attendance-grades-migrate
  docker compose run --rm students-migrate
  docker compose run --rm enrollment-migrate
  docker compose run --rm tickets-migrate
  docker compose --profile manual run --rm tickets-catalog-bootstrap
  docker compose run --rm study-plans-migrate
  docker compose run --rm --no-deps postgres-privileges
  docker compose up -d --no-deps gateway auth academic students enrollment attendance-grades exams payments tickets study-plans
}

install_study_plans_host() {
  if [ -x "$DEPLOY_DIR/scripts/install-study-plans-apache-host.sh" ]; then
    bash "$DEPLOY_DIR/scripts/install-study-plans-apache-host.sh" || log "El virtual host de planes no quedó activo. Revisa el certificado de planes.uprit.edu.pe."
  fi
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
  tickets-frontend)
    update_repo "$TICKETS_FRONTEND_DIR" "$SOURCE_SHA"
    cd "$DEPLOY_DIR"
    docker compose build tickets-frontend
    docker compose up -d --no-deps tickets-frontend
    ;;
  identity-frontend)
    update_repo "$IDENTITY_FRONTEND_DIR" "$SOURCE_SHA"
    cd "$DEPLOY_DIR"
    docker compose build identity-frontend
    docker compose up -d --no-deps identity-frontend
    ;;
  backend)
    update_repo "$BACKEND_DIR" "$SOURCE_SHA"
    prepare_env
    backup_database
    release_backend
    ;;
  deploy|all|"")
    update_repo "$DEPLOY_DIR" "$SOURCE_SHA"
    update_repo "$BACKEND_DIR"
    update_repo "$FRONTEND_DIR"
    update_repo "$TICKETS_FRONTEND_DIR"
    update_repo "$IDENTITY_FRONTEND_DIR"
    ensure_checkout "$STUDY_PLANS_FRONTEND_DIR" "$STUDY_PLANS_FRONTEND_URL"
    log "Comparando el estado del despliegue"
    set +o pipefail
    deployment_state > "${DEPLOY_STATE_FILE}.next"
    set -o pipefail
    if [ -f "$DEPLOY_STATE_FILE" ] && cmp -s "$DEPLOY_STATE_FILE" "${DEPLOY_STATE_FILE}.next"; then
      log "Los commits actuales ya están desplegados; se comprueba que los servicios sigan en pie"
      cd "$DEPLOY_DIR"
      docker compose up -d --remove-orphans --wait --wait-timeout 180
      docker compose up -d --no-deps --force-recreate reverse-proxy
      docker compose up -d --wait --wait-timeout 180 reverse-proxy
    else
    cd "$DEPLOY_DIR"
    prepare_env
    backup_database
    docker compose build gateway frontend tickets-frontend identity-frontend study-plans-frontend auth-migrate academic-migrate payments-migrate attendance-grades-migrate students-migrate enrollment-migrate tickets-migrate study-plans-migrate
    docker compose run --rm auth-migrate
    docker compose --profile manual run --rm auth-tickets-bootstrap
    docker compose run --rm academic-migrate
    docker compose run --rm payments-migrate
    docker compose run --rm attendance-grades-migrate
    docker compose run --rm students-migrate
    docker compose run --rm enrollment-migrate
    docker compose run --rm tickets-migrate
    docker compose --profile manual run --rm tickets-catalog-bootstrap
    docker compose run --rm study-plans-migrate
    docker compose run --rm --no-deps postgres-privileges
    # Wait until dependency-gated services such as reverse-proxy have actually
    # started. Without --wait Compose can return while a service remains only
    # in the Created state after its dependencies become healthy.
    docker compose up -d --remove-orphans --wait --wait-timeout 180
    # Git updates bind-mounted Nginx files by replacing their inode. Recreate
    # only the proxy so it mounts the updated configuration without restarting
    # the application or data services.
    docker compose up -d --no-deps --force-recreate reverse-proxy
    docker compose up -d --wait --wait-timeout 180 reverse-proxy
    install_study_plans_host
    SAVE_DEPLOYMENT_STATE=true
    fi
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
