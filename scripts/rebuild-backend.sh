#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

cd "$REPOSITORY_ROOT"

if [[ ! -f .env ]]; then
  echo 'Falta ci-deploy/.env. Cópialo desde .env.example y configura sus valores antes de ejecutar este comando.' >&2
  exit 1
fi

echo 'Construyendo la imagen del backend y la imagen de migraciones…'
docker compose --env-file .env -f docker-compose.yml build gateway auth-migrate academic-migrate payments-migrate attendance-grades-migrate students-migrate enrollment-migrate

echo 'Aplicando migraciones pendientes del servicio auth…'
docker compose --env-file .env -f docker-compose.yml run --rm auth-migrate
docker compose --env-file .env -f docker-compose.yml run --rm academic-migrate
docker compose --env-file .env -f docker-compose.yml run --rm payments-migrate
docker compose --env-file .env -f docker-compose.yml run --rm attendance-grades-migrate
docker compose --env-file .env -f docker-compose.yml run --rm students-migrate
docker compose --env-file .env -f docker-compose.yml run --rm enrollment-migrate

echo 'Recreando microservicios y Gateway, sin reiniciar frontend ni infraestructura…'
docker compose --env-file .env -f docker-compose.yml up -d --no-deps --force-recreate \
  gateway auth academic students enrollment attendance-grades exams payments

echo 'Esperando la comprobación de salud del Gateway…'
for attempt in {1..20}; do
  if docker compose --env-file .env -f docker-compose.yml exec -T gateway \
    node -e "fetch('http://127.0.0.1:3000/api/v1/health').then((response) => process.exit(response.ok ? 0 : 1)).catch(() => process.exit(1))"; then
    echo 'Backend reconstruido correctamente. El frontend y la infraestructura no se reiniciaron.'
    exit 0
  fi
  sleep 2
done

echo 'El Gateway no superó la comprobación de salud. Revisa: docker compose logs --tail=100 gateway auth' >&2
exit 1
