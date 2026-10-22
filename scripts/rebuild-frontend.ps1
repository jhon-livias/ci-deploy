[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repositoryRoot

if (-not (Test-Path '.env')) {
    throw 'Falta ci-deploy/.env. Cópialo desde .env.example y configura sus valores antes de ejecutar este comando.'
}

docker compose --env-file .env -f docker-compose.yml up -d --build --no-deps frontend

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host 'Frontend reconstruido. Abre o recarga http://localhost:8080/.'
