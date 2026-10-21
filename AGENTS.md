# Instrucciones para agentes — ci-deploy

Repositorio de CD y orquestación. No aloja código de negocio ni secretos.

- `docker-compose.yml` orquesta únicamente los repositorios hermanos `../ci-backend` y `../ci-frontend` más infraestructura.
- Cada aplicación mantiene su propio `Dockerfile` y workflow CI. Este repositorio solo ejecuta CD tras recibir `repository_dispatch` validado.
- Un despliegue `frontend` no reconstruye backend; uno `backend` no reconstruye frontend. Cambios de `ci-deploy` pueden desplegar el stack completo.
- Mantén todos los servicios salvo `reverse-proxy` sin puertos del host y en red Docker interna.
- Nunca agregues secretos a Compose, workflows, imágenes o Git. Se leen desde `.env` no versionado o un gestor de secretos del entorno.
- Producción requiere TLS en un proxy confiable, imágenes versionadas y actualizadas, cuentas sin privilegios, límites de recursos, backups y revisión de `docker compose config` antes de desplegar.
