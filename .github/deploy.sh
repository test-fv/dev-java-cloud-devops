 GNU nano 7.2              /home/azureuser/app/deploy.sh
#!/bin/bash

ACR_NAME="acrportfoliofabian"
IMAGE_NAME="portfolioapp"
TAG="latest"

echo "Login ACR..."
az acr login --name $ACR_NAME

echo "Pull latest image..."
docker pull $ACR_NAME.azurecr.io/$IMAGE_NAME:$TAG

echo "Stop old container..."
docker stop portfolioapp || true
docker rm portfolioapp || true

echo "Run new container..."
docker run -d \
  -p 80:8080 \
  --name portfolioapp \
