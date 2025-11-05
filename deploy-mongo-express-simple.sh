#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Mongo Express Simple Deployment with Basic Auth ===${NC}"

# Check if running as administrator user
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root!${NC}"
   exit 1
fi

# Load MongoDB environment
MONGODB_ENV="$HOME/projects/secrets/mongodb.env"
if [ ! -f "$MONGODB_ENV" ]; then
    echo -e "${RED}MongoDB environment file not found!${NC}"
    echo "Deploy MongoDB first: cd /home/administrator/projects/mongodb && ./deploy.sh"
    exit 1
fi

source "$MONGODB_ENV"

# Load Mongo Express Simple environment
MONGO_EXPRESS_SIMPLE_ENV="$HOME/projects/secrets/mongo-express-simple.env"
if [ ! -f "$MONGO_EXPRESS_SIMPLE_ENV" ]; then
    echo -e "${YELLOW}Creating Mongo Express Simple environment file...${NC}"
    cat > "$MONGO_EXPRESS_SIMPLE_ENV" << 'EOF'
# Mongo Express Simple Deployment (Basic Auth)
# Generated: $(date +%Y-%m-%d)

# Basic Authentication Credentials
ME_CONFIG_BASICAUTH_USERNAME=admin
ME_CONFIG_BASICAUTH_PASSWORD=MongoExpress2025!

# Session Secrets
ME_CONFIG_SITE_COOKIESECRET=$(openssl rand -base64 32)
ME_CONFIG_SITE_SESSIONSECRET=$(openssl rand -base64 32)
EOF
    echo -e "${GREEN}Created $MONGO_EXPRESS_SIMPLE_ENV${NC}"
fi

source "$MONGO_EXPRESS_SIMPLE_ENV"

# Check if MongoDB is running
if ! docker ps --format '{{.Names}}' | grep -qx "mongodb"; then
    echo -e "${RED}MongoDB is not running!${NC}"
    echo "Start MongoDB first: cd /home/administrator/projects/mongodb && ./deploy.sh"
    exit 1
fi

# Stop and remove existing containers
echo -e "${YELLOW}Stopping existing Mongo Express containers...${NC}"
docker kill mongo-express mongo-express-auth-proxy 2>/dev/null || true
docker rm mongo-express mongo-express-auth-proxy 2>/dev/null || true

# Deploy Mongo Express with basic auth
echo -e "${YELLOW}Deploying Mongo Express with basic authentication...${NC}"
docker run -d \
  --name mongo-express \
  --restart unless-stopped \
  --network mongodb-net \
  -e ME_CONFIG_MONGODB_SERVER=mongodb \
  -e ME_CONFIG_MONGODB_PORT=27017 \
  -e ME_CONFIG_MONGODB_ADMINUSERNAME="$MONGO_INITDB_ROOT_USERNAME" \
  -e ME_CONFIG_MONGODB_ADMINPASSWORD="$MONGO_INITDB_ROOT_PASSWORD" \
  -e ME_CONFIG_BASICAUTH=true \
  -e ME_CONFIG_BASICAUTH_USERNAME="$ME_CONFIG_BASICAUTH_USERNAME" \
  -e ME_CONFIG_BASICAUTH_PASSWORD="$ME_CONFIG_BASICAUTH_PASSWORD" \
  -e ME_CONFIG_SITE_COOKIESECRET="${ME_CONFIG_SITE_COOKIESECRET:-$(openssl rand -base64 32)}" \
  -e ME_CONFIG_SITE_SESSIONSECRET="${ME_CONFIG_SITE_SESSIONSECRET:-$(openssl rand -base64 32)}" \
  -e ME_CONFIG_SITE_BASEURL=/ \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=traefik-net" \
  --label "traefik.http.routers.mongo-express.rule=Host(\`mongo.ai-servicers.com\`)" \
  --label "traefik.http.routers.mongo-express.entrypoints=websecure" \
  --label "traefik.http.routers.mongo-express.tls=true" \
  --label "traefik.http.routers.mongo-express.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.mongo-express.loadbalancer.server.port=8081" \
  mongo-express:latest

# Connect to traefik-net network for web access
echo -e "${YELLOW}Connecting to traefik-net network...${NC}"
docker network connect traefik-net mongo-express 2>/dev/null || echo "Already connected"

echo -e "${YELLOW}Waiting for container to start...${NC}"
sleep 10

# Check container status
if docker ps | grep -q mongo-express; then
    echo ""
    echo -e "${GREEN}=== Deployment Complete ===${NC}"
    echo ""
    echo -e "${GREEN}Access Mongo Express at:${NC} https://mongo.ai-servicers.com"
    echo ""
    echo -e "${GREEN}Credentials:${NC}"
    echo "  Username: $ME_CONFIG_BASICAUTH_USERNAME"
    echo "  Password: [see $MONGO_EXPRESS_SIMPLE_ENV]"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo "  Check logs: docker logs mongo-express --tail 20"
    echo "  Restart:    docker restart mongo-express"
    echo ""
    echo -e "${YELLOW}Security Note:${NC}"
    echo "  Using basic authentication for simplicity"
    echo "  Consider upgrading to Keycloak SSO later"
else
    echo -e "${RED}Failed to start Mongo Express${NC}"
    echo "Check logs: docker logs mongo-express"
    exit 1
fi