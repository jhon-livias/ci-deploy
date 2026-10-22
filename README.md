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
docker compose build gateway frontend auth-migrate
docker compose up -d
```

El Gateway queda disponible detrás del proxy en `/api/`; la SPA en `/`. Comprueba la API con:

```bash
curl -fsS http://127.0.0.1:8080/api/v1/health
```

## Primera cuenta administradora

Antes de iniciar sesión, define en `.env` un valor aleatorio de al menos 32
caracteres para `AUTH_JWT_ACCESS_SECRET`. Para uso HTTP local define además
`AUTH_COOKIE_SECURE=false`; en producción HTTPS debe permanecer en `true`.

Después de que `auth-migrate` haya terminado correctamente, crea una única
cuenta administradora con variables efímeras de shell; la contraseña no se
guarda en Compose, Git ni logs:

```bash
docker compose run --rm \
  -e ADMIN_USERNAME=admin \
  -e ADMIN_EMAIL=admin@uprit.edu.pe \
  -e ADMIN_DOCUMENT_NUMBER=00000000 \
  -e ADMIN_FIRST_NAME=Nombre \
  -e ADMIN_PATERNAL_LAST_NAME=Apellido \
  -e ADMIN_PASSWORD='una-contraseña-larga-y-unica' \
  auth-admin-bootstrap
```

El comando falla sin modificar datos si el usuario o correo ya existen. Luego
ingresa por la SPA: el rol `ADMINISTRATOR` se redirige a `/administracion`.

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

En Git Bash, para reconstruir únicamente el frontend local después de un cambio:

```bash
bash scripts/rebuild-frontend.sh
```

Para reconstruir los microservicios y el Gateway, aplicar migraciones pendientes
de Auth y conservar frontend e infraestructura en ejecución:

```bash
bash scripts/rebuild-backend.sh
```

En PowerShell también está disponible:

```powershell
.\scripts\rebuild-frontend.ps1
```

No reinicia el backend, las bases de datos ni el proxy. Si el navegador conserva
archivos previos, usa `Ctrl + F5`.

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

