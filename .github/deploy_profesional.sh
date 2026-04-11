#!/usr/bin/env bash

##################################################
# Production Ready Docker Deploy Script
# Compatible: Azure VM + ACR + GitHub Actions
##################################################

set -Eeuo pipefail

########## CONFIGURACIÓN (PARAMETRIZABLE) ##########

ACR_NAME=${ACR_NAME:-acrportfoliofabian}
IMAGE_NAME=${IMAGE_NAME:-portfolioapp}
TAG=${TAG:-latest}

APP_PORT=${APP_PORT:-3000}
CONTAINER_PORT=${CONTAINER_PORT:-8080}

CONTAINER_NAME=${CONTAINER_NAME:-portfolioapp}

IMAGE="$ACR_NAME.azurecr.io/$IMAGE_NAME:$TAG"

########## LOGGING ##########

log() {
  echo "[DEPLOY] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

########## ERROR HANDLER ##########

trap 'log "❌ Error en línea $LINENO"' ERR

########## PRECHECKS ##########

log "Validando dependencias..."

command -v docker >/dev/null || { log "Docker no instalado"; exit 1; }
command -v az >/dev/null || { log "Azure CLI no instalado"; exit 1; }

########## LOGIN ACR ##########

log "Login en Azure Container Registry..."

az acr login --name "$ACR_NAME"

########## PULL NUEVA IMAGEN ##########

log "Descargando imagen: $IMAGE"

if ! docker pull "$IMAGE"; then
  log "❌ Falló descarga de imagen"
  exit 1
fi

########## GUARDAR IMAGEN ACTUAL ##########

PREVIOUS_IMAGE=$(docker inspect "$CONTAINER_NAME" \
  --format='{{.Config.Image}}' 2>/dev/null || true)

if [ -n "$PREVIOUS_IMAGE" ]; then
  log "Imagen anterior detectada: $PREVIOUS_IMAGE"
else
  log "No existe versión previa"
fi

########## DETENER CONTENEDOR ##########

log "Deteniendo contenedor actual..."

docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

########## LEVANTAR NUEVA VERSION ##########

log "Iniciando nueva versión..."

docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$APP_PORT:$CONTAINER_PORT" \
  --restart unless-stopped \
  "$IMAGE"

########## HEALTH CHECK ##########

log "Esperando inicialización..."
sleep 8

log "Ejecutando health check..."

if ! curl -fs "http://localhost:$APP_PORT" >/dev/null; then

  log "❌ Health check falló"

  if [ -n "$PREVIOUS_IMAGE" ]; then
    log "🔁 Ejecutando rollback..."

    docker stop "$CONTAINER_NAME" || true
    docker rm "$CONTAINER_NAME" || true

    docker run -d \
      --name "$CONTAINER_NAME" \
      -p "$APP_PORT:$CONTAINER_PORT" \
      --restart unless-stopped \
      "$PREVIOUS_IMAGE"

    log "✅ Rollback completado"
  fi

  exit 1
fi

########## LIMPIEZA ##########

log "Limpiando imágenes antiguas..."
docker image prune -f

########## RESULTADO FINAL ##########

log "✅ Deploy exitoso"

docker ps --filter "name=$CONTAINER_NAME"

echo ""
log "Aplicación disponible en:"
echo "http://$(curl -s ifconfig.me):$APP_PORT"