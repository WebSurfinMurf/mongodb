#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Mongo Express Deployment with Keycloak OAuth2 ===${NC}"

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

# Check if MongoDB is running
if ! docker ps --format '{{.Names}}' | grep -qx "mongodb"; then
    echo -e "${RED}MongoDB is not running!${NC}"
    echo "Start MongoDB first: cd /home/administrator/projects/mongodb && ./deploy.sh"
    exit 1
fi

# Create Mongo Express environment file if it doesn't exist
MONGO_EXPRESS_ENV="$HOME/projects/secrets/mongo-express.env"
if [ ! -f "$MONGO_EXPRESS_ENV" ]; then
    echo -e "${YELLOW}Creating Mongo Express environment file...${NC}"
    
    # Generate cookie secret
    COOKIE_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | head -c 32; echo "=")
    
    cat > "$MONGO_EXPRESS_ENV" << EOF
# Mongo Express with OAuth2 Proxy Configuration
# Generated: $(date +%Y-%m-%d)

# OAuth2 Proxy Configuration (UPDATE THESE!)
OAUTH2_PROXY_CLIENT_ID=mongodb
OAUTH2_PROXY_CLIENT_SECRET=PLACEHOLDER_GET_FROM_KEYCLOAK
OAUTH2_PROXY_COOKIE_SECRET=$COOKIE_SECRET
OAUTH2_PROXY_PROVIDER=keycloak-oidc
OAUTH2_PROXY_OIDC_ISSUER_URL=https://keycloak.ai-servicers.com/realms/master
OAUTH2_PROXY_SKIP_OIDC_DISCOVERY=true
OAUTH2_PROXY_OIDC_JWKS_URL=http://keycloak:8080/realms/master/protocol/openid-connect/certs
OAUTH2_PROXY_LOGIN_URL=https://keycloak.ai-servicers.com/realms/master/protocol/openid-connect/auth
OAUTH2_PROXY_REDEEM_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token
OAUTH2_PROXY_REDIRECT_URL=https://mongodb.ai-servicers.com/oauth2/callback
OAUTH2_PROXY_EMAIL_DOMAINS=*
OAUTH2_PROXY_COOKIE_SECURE=true
OAUTH2_PROXY_UPSTREAMS=http://mongo-express:8081/
OAUTH2_PROXY_PASS_HOST_HEADER=false
OAUTH2_PROXY_PROXY_PREFIX=/oauth2
OAUTH2_PROXY_SET_AUTHORIZATION_HEADER=true
OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:4180
OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true
OAUTH2_PROXY_PASS_USER_HEADERS=true
OAUTH2_PROXY_SET_XAUTHREQUEST=true

# Don't request groups scope explicitly - use default scopes  
OAUTH2_PROXY_SCOPE=openid email profile
# Restrict to administrators group
OAUTH2_PROXY_ALLOWED_GROUPS=/administrators

# MongoDB Connection for Mongo Express
ME_CONFIG_MONGODB_SERVER=mongodb
ME_CONFIG_MONGODB_PORT=27017
ME_CONFIG_MONGODB_ADMINUSERNAME=$MONGO_INITDB_ROOT_USERNAME
ME_CONFIG_MONGODB_ADMINPASSWORD=$MONGO_INITDB_ROOT_PASSWORD

# Mongo Express Settings (no auth needed, OAuth2 handles it)
ME_CONFIG_BASICAUTH=false
ME_CONFIG_SITE_BASEURL=/
ME_CONFIG_SITE_COOKIESECRET=$(openssl rand -base64 32)
ME_CONFIG_SITE_SESSIONSECRET=$(openssl rand -base64 32)
ME_CONFIG_OPTIONS_EDITORTHEME=ambiance
ME_CONFIG_MONGODB_ENABLE_ADMIN=true
EOF
    echo -e "${GREEN}Created $MONGO_EXPRESS_ENV${NC}"
    echo ""
    echo -e "${RED}IMPORTANT: You must now:${NC}"
    echo "1. Create 'mongodb' client in Keycloak"
    echo "2. Get the client secret from Keycloak"
    echo "3. Update OAUTH2_PROXY_CLIENT_SECRET in $MONGO_EXPRESS_ENV"
    echo "4. Run this script again"
    exit 1
fi

source "$MONGO_EXPRESS_ENV"

# Verify OAuth2 client secret is configured
if [ "$OAUTH2_PROXY_CLIENT_SECRET" = "PLACEHOLDER_GET_FROM_KEYCLOAK" ] || [ -z "$OAUTH2_PROXY_CLIENT_SECRET" ]; then
    echo -e "${RED}OAuth2 client secret not configured!${NC}"
    echo ""
    echo -e "${BLUE}Please:${NC}"
    echo "1. Log into Keycloak at https://keycloak.ai-servicers.com/admin/"
    echo "2. Create client 'mongodb' (or check if it exists)"
    echo "3. Get the client secret from Credentials tab"
    echo "4. Update OAUTH2_PROXY_CLIENT_SECRET in:"
    echo "   $MONGO_EXPRESS_ENV"
    echo "5. Run this script again"
    exit 1
fi

# Stop and remove existing containers
echo -e "${YELLOW}Stopping existing Mongo Express containers...${NC}"
docker kill mongo-express mongo-express-auth-proxy 2>/dev/null || true
docker rm mongo-express mongo-express-auth-proxy 2>/dev/null || true

# Verify containers are stopped
if docker ps | grep -q "mongo-express"; then
    echo -e "${RED}Failed to stop containers. Please stop them manually.${NC}"
    exit 1
fi

# Deploy Mongo Express (internal only, no Traefik labels)
echo -e "${YELLOW}Deploying Mongo Express...${NC}"
docker run -d \
  --name mongo-express \
  --restart unless-stopped \
  --network mongodb-net \
  -e ME_CONFIG_MONGODB_SERVER="$ME_CONFIG_MONGODB_SERVER" \
  -e ME_CONFIG_MONGODB_PORT="$ME_CONFIG_MONGODB_PORT" \
  -e ME_CONFIG_MONGODB_ADMINUSERNAME="$ME_CONFIG_MONGODB_ADMINUSERNAME" \
  -e ME_CONFIG_MONGODB_ADMINPASSWORD="$ME_CONFIG_MONGODB_ADMINPASSWORD" \
  -e ME_CONFIG_BASICAUTH=false \
  -e ME_CONFIG_SITE_BASEURL="/" \
  -e ME_CONFIG_SITE_COOKIESECRET="${ME_CONFIG_SITE_COOKIESECRET:-$(openssl rand -base64 32)}" \
  -e ME_CONFIG_SITE_SESSIONSECRET="${ME_CONFIG_SITE_SESSIONSECRET:-$(openssl rand -base64 32)}" \
  -e ME_CONFIG_OPTIONS_EDITORTHEME="${ME_CONFIG_OPTIONS_EDITORTHEME:-ambiance}" \
  -e ME_CONFIG_MONGODB_ENABLE_ADMIN="${ME_CONFIG_MONGODB_ENABLE_ADMIN:-true}" \
  mongo-express:latest

# Ensure mongo-express is resolvable by name on the network
echo -e "${YELLOW}Configuring network alias...${NC}"
docker network disconnect mongodb-net mongo-express 2>/dev/null || true
docker network connect --alias mongo-express mongodb-net mongo-express

# Also connect to traefik-net for OAuth2 proxy
docker network connect traefik-net mongo-express 2>/dev/null || true

# Deploy OAuth2 Proxy with Traefik labels
echo -e "${YELLOW}Deploying OAuth2 Proxy for Mongo Express...${NC}"
docker run -d \
  --name mongo-express-auth-proxy \
  --restart unless-stopped \
  --network mongodb-net \
  --env-file "$MONGO_EXPRESS_ENV" \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=traefik-net" \
  --label "traefik.http.routers.mongo-express.rule=Host(\`mongodb.ai-servicers.com\`)" \
  --label "traefik.http.routers.mongo-express.entrypoints=websecure" \
  --label "traefik.http.routers.mongo-express.tls=true" \
  --label "traefik.http.routers.mongo-express.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.mongo-express.loadbalancer.server.port=4180" \
  quay.io/oauth2-proxy/oauth2-proxy:latest

# Connect OAuth2 proxy to traefik-net and keycloak-net
docker network connect traefik-net mongo-express-auth-proxy 2>/dev/null || true
echo -e "${YELLOW}Connecting OAuth2 proxy to keycloak-net...${NC}"
docker network create keycloak-net 2>/dev/null || echo "Network keycloak-net already exists"
docker network connect keycloak-net mongo-express-auth-proxy 2>/dev/null || true

echo -e "${YELLOW}Waiting for containers to start...${NC}"
sleep 10

# Check container status
echo -e "${YELLOW}Container status:${NC}"
docker ps | grep mongo-express | awk '{print $NF, $7, $8, $9}'

# Test internal connectivity
echo -e "${YELLOW}Testing internal connectivity...${NC}"
if docker run --rm --network mongodb-net alpine ping -c 1 mongo-express >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Network alias working${NC}"
else
    echo -e "${RED}✗ Network alias not working${NC}"
fi

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo -e "${GREEN}Access Mongo Express at:${NC} https://mongodb.ai-servicers.com"
echo ""
echo -e "${YELLOW}Authentication:${NC}"
echo "  Uses Keycloak SSO (administrators group only)"
echo "  Login with your Keycloak credentials"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  Check logs:       docker logs mongo-express --tail 20"
echo "  Check auth logs:  docker logs mongo-express-auth-proxy --tail 20"
echo "  Check session:    https://mongodb.ai-servicers.com/oauth2/userinfo"
echo "  Restart:          docker restart mongo-express mongo-express-auth-proxy"
echo ""
echo -e "${YELLOW}Features:${NC}"
echo "  • Browse all databases and collections"
echo "  • View/edit documents"
echo "  • Run queries and aggregations"
echo "  • Manage indexes"
echo "  • Import/export data"
echo "  • User management"
echo ""

# Check if group restriction is enabled
if grep -q "^OAUTH2_PROXY_ALLOWED_GROUPS=" "$MONGO_EXPRESS_ENV"; then
    echo -e "${GREEN}Group restriction: ENABLED (administrators only)${NC}"
else
    echo -e "${YELLOW}Group restriction: DISABLED (all authenticated users)${NC}"
    echo "To enable: Set OAUTH2_PROXY_ALLOWED_GROUPS in mongo-express.env"
fi