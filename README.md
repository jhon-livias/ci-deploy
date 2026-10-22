# ci-deploy

Repositorio independiente de CD y orquestación Docker del centro de idiomas. No contiene el código de las aplicaciones ni secretos.

## Topología

```text
/opt/ci/
├── ci-backend/   # Dockerfile + CI; NestJS microservices
├── ci-frontend/  # Dockerfile + CI; Angular SPA
└── ci-deploy/    # este repositorio: Compose, proxy y CD
```

`ci-deploy` construye las imágenes desde los repositorios hermanos. Solo `reverse-proxy` publica un puerto del host (está además en la red `edge`, porque Docker no publica puertos desde redes `internal: true`); API, frontend, PostgreSQL, Redis, RabbitMQ y MinIO viven en la red Docker interna.

## Preparación local o VPS

```bash
mkdir -p /opt/ci && cd /opt/ci
git clone <url-backend> ci-backend
git clone <url-frontend> ci-frontend
git clone <url-deploy> ci-deploy
cd ci-deploy
cp .env.example .env
# Reemplaza todas las contraseñas de .env por valores únicos y seguros.
docker compose build gateway frontend
docker compose up -d
```

El Gateway queda disponible detrás del proxy en `/api/`; la SPA en `/`. Comprueba la API con:

```bash
curl -fsS http://127.0.0.1:8080/api/v1/health
```

## Producción

Expón el puerto `HTTP_PORT` únicamente detrás de un balanceador o proxy TLS administrado que fuerce HTTPS y sobrescriba los encabezados `X-Forwarded-*`. No publiques PostgreSQL, Redis, RabbitMQ, MinIO ni los puertos internos de NestJS.

Configura en el repositorio `ci-deploy` los secrets de GitHub Actions `VPS_HOST`, `VPS_USER` y `VPS_SSH_KEY`. En `ci-backend` y `ci-frontend`, configura:

- Variable `DEPLOY_REPOSITORY`: `<organización-o-usuario>/ci-deploy`.
- Secret `DEPLOY_DISPATCH_TOKEN`: token fine-grained con permiso para crear `repository_dispatch` solo en `ci-deploy`.

Consulta [la plantilla de valores de Actions](.github/SECRETS.template.md) para
el formato correcto de una clave AWS `.pem`. Guarda cualquier valor real solo
en GitHub Secrets; el archivo local `.github/SECRETS.md` está ignorado por Git.

Un push validado a `main` de `ci-frontend` emite `component=frontend`; solo se construye y recrea el contenedor frontend. Un push validado de `ci-backend` emite `component=backend`; se reconstruye una imagen y se recrean Gateway y microservicios NestJS. Un cambio en este repositorio despliega todo el stack.

## Operación

```bash
# Despliegue manual de un componente, desde el VPS
SOURCE_COMPONENT=frontend bash scripts/deploy-production.sh
SOURCE_COMPONENT=backend bash scripts/deploy-production.sh

# Estado y logs
docker compose ps
docker compose logs --tail=100 gateway frontend reverse-proxy
```

Antes de producción, protege las ramas `main`, revisa los workflows, crea copias de seguridad de PostgreSQL/MinIO y realiza una restauración de prueba.

## HTTPS, observabilidad y backups (portado de nm-deploy)

```bash
# HTTPS 80/443 con Let's Encrypt (certificado 'ci', renovación automática)
CI_DOMAINS='ci.example.com' LE_EMAIL=admin@example.com bash scripts/issue-certificate.sh
# Luego añade a .env: PROXY_CONF=default.ssl.conf y COMPOSE_FILE=docker-compose.yml:docker-compose.edge.yml

# Observabilidad (Loki + Promtail + Grafana en 127.0.0.1:3010; usa túnel SSH)
docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d

# Backups (PostgreSQL + MinIO), validación sin tocar producción y restauración
bash scripts/backup-full.sh
bash scripts/validate-restore-backup.sh
RESTORE_CONFIRM=yes bash scripts/restore-full.sh backups/<fecha>
bash scripts/docker-cleanup.sh
```

