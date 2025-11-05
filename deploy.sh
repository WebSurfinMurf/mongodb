#!/bin/bash
set -e

echo "🚀 Deploying MongoDB Stack"
echo "==================================="
echo ""

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Environment file
ENV_FILE="$HOME/projects/secrets/mongo-express.env"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Pre-deployment Checks ---
echo "🔍 Pre-deployment checks..."

# Check environment file
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file not found: $ENV_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Environment file exists${NC}"

# Source environment variables
set -o allexport
source "$ENV_FILE"
set +o allexport

# Validate required variables
required_vars=("MONGO_INITDB_ROOT_USERNAME" "MONGO_INITDB_ROOT_PASSWORD" "KEYCLOAK_CLIENT_SECRET" "OAUTH2_COOKIE_SECRET")

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo -e "${RED}❌ Required variable $var is not set${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✅ Environment variables validated${NC}"

# Check if networks exist
for network in mongodb-net traefik-net keycloak-net; do
    if ! docker network inspect "$network" &>/dev/null; then
        echo -e "${RED}❌ $network network not found${NC}"
        echo "Run: /home/administrator/projects/infrastructure/setup-networks.sh"
        exit 1
    fi
done
echo -e "${GREEN}✅ All required networks exist${NC}"

# Check/create volumes
for volume in mongodb_data mongodb_config; do
    if ! docker volume inspect "$volume" &>/dev/null; then
        echo "Creating $volume volume..."
        docker volume create "$volume"
    fi
done
echo -e "${GREEN}✅ MongoDB volumes ready${NC}"

# Validate docker-compose.yml syntax
echo ""
echo "✅ Validating docker-compose.yml..."
if ! docker compose config > /dev/null 2>&1; then
    echo -e "${RED}❌ docker-compose.yml validation failed${NC}"
    docker compose config
    exit 1
fi
echo -e "${GREEN}✅ docker-compose.yml is valid${NC}"

# --- Deployment ---
echo ""
echo "🚀 Deploying MongoDB stack..."
docker compose up -d --remove-orphans

# --- Post-deployment Validation ---
echo ""
echo "⏳ Waiting for MongoDB to be ready..."
timeout 60 bash -c 'until docker exec mongodb mongosh --eval "db.adminCommand(\"ping\")" --quiet 2>/dev/null | grep -q "ok"; do sleep 2; done' || {
    echo -e "${RED}❌ MongoDB failed to start${NC}"
    docker logs mongodb --tail 30
    exit 1
}
echo -e "${GREEN}✅ MongoDB is ready${NC}"

echo ""
echo "⏳ Waiting for Mongo Express to be ready..."
timeout 30 bash -c 'until docker logs mongo-express 2>&1 | grep -q "Mongo Express server listening"; do sleep 2; done' || {
    echo -e "${RED}❌ Mongo Express failed to start${NC}"
    docker logs mongo-express --tail 30
    exit 1
}
echo -e "${GREEN}✅ Mongo Express is ready${NC}"

echo ""
echo "⏳ Waiting for OAuth2 proxy to be ready..."
sleep 5  # Give proxy time to initialize
docker run --rm --network traefik-net alpine/curl:latest curl -sI http://mongo-express-auth-proxy:4180 | grep -q "HTTP" || {
    echo -e "${RED}❌ OAuth2 proxy failed to start${NC}"
    docker logs mongo-express-auth-proxy --tail 30
    exit 1
}
echo -e "${GREEN}✅ OAuth2 proxy is ready${NC}"

# Get database list
echo ""
echo "📊 Database Status:"
docker exec mongodb mongosh --eval "db.adminCommand('listDatabases')" --quiet 2>/dev/null | grep -E "name|sizeOnDisk" | head -20

# --- Summary ---
echo ""
echo "=========================================="
echo "✅ MongoDB Deployment Summary"
echo "=========================================="
echo "Containers:"
echo "  - mongodb (${MONGO_VERSION:-6.0})"
echo "  - mongo-express (web UI)"
echo "  - mongo-express-auth-proxy (OAuth2)"
echo ""
echo "Networks:"
echo "  - mongodb-net (database access)"
echo "  - traefik-net (web routing)"
echo "  - keycloak-net (authentication)"
echo ""
echo "Volumes:"
echo "  - mongodb_data (database files)"
echo "  - mongodb_config (configuration)"
echo ""
echo "Access:"
echo "  - Web UI: https://mongodb.ai-servicers.com"
echo "  - Internal: mongodb://mongodb:27017"
echo "  - External: mongodb://localhost:27017"
echo ""
echo "=========================================="
echo ""
echo "📊 View logs:"
echo "   docker logs mongodb -f"
echo "   docker logs mongo-express -f"
echo ""
echo "🔍 Connect via mongosh:"
echo "   docker exec -it mongodb mongosh -u ${MONGO_INITDB_ROOT_USERNAME}"
echo ""
echo "✅ Deployment complete!"
