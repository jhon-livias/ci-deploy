# Plantilla de secretos para GitHub Actions

Configura estos valores en **Settings > Secrets and variables > Actions**.
No guardes claves privadas, contraseñas ni tokens en el repositorio.

## Repositorio `ci-deploy`

| Tipo | Nombre | Valor |
| --- | --- | --- |
| Secret | `VPS_HOST` | DNS o IP pública de la instancia EC2. |
| Secret | `VPS_USER` | Usuario del sistema; normalmente `ubuntu` para Ubuntu. |
| Secret | `VPS_SSH_KEY` | Contenido completo de la clave privada `.pem`. |
| Secret | `VPS_SSH_PASSPHRASE` | Solo si la clave está cifrada con passphrase. |

El secret `VPS_SSH_KEY` debe conservar sus saltos de línea:

```text
-----BEGIN ... PRIVATE KEY-----
contenido real de la clave
-----END ... PRIVATE KEY-----
```

## Repositorios de aplicación

En `ci-backend` y `ci-frontend`:

| Tipo | Nombre | Valor |
| --- | --- | --- |
| Variable | `DEPLOY_REPOSITORY` | `<usuario-u-organización>/ci-deploy` |
| Secret | `DEPLOY_DISPATCH_TOKEN` | Token fine-grained limitado al repositorio de despliegue, con permiso `Contents: Read and write`. |
