# MongoDB Central Instance

## Project Overview
Central MongoDB instance shared by multiple services to minimize technology variations and simplify management.

## Current Status
- **Status**: ✅ RUNNING (Fixed session secret error)
- **Container**: mongodb
- **Version**: 6.0
- **Port**: 27017
- **Network**: mongodb-net
- **Created**: 2025-08-24
- **Last Updated**: 2025-08-25
- **Web UI**: ✅ Working at https://mongodb.ai-servicers.com

## Architecture
```
Central MongoDB (port 27017)
    ├── ShellHub (shellhub_db)
    ├── [Future Service 1]
    └── [Future Service 2]
    
Mongo Express (Web UI)
    └── OAuth2 Proxy → Keycloak SSO
```

## Access Methods
- **Direct Connection**: mongodb:27017 (from Docker containers)
- **Host Connection**: localhost:27017 (from host machine)
- **Web UI**: https://mongodb.ai-servicers.com (Mongo Express with Keycloak SSO)

## Files & Paths
- **Deploy Script**: `/home/administrator/projects/mongodb/deploy.sh` (MongoDB server)
- **Web UI Scripts**: 
  - `/home/administrator/projects/mongodb/deploy-mongo-express.sh` (SSO version)
  - `/home/administrator/projects/mongodb/deploy-mongo-express-simple.sh` (Basic auth)
- **Utility Scripts**:
  - `/home/administrator/projects/mongodb/add-service-db.sh` (Create service databases)
  - `/home/administrator/projects/mongodb/setup-keycloak.sh` (Keycloak setup guide)
- **Environment Files**:
  - `$HOME/projects/secrets/mongodb.env` (MongoDB credentials)
  - `$HOME/projects/secrets/mongo-express.env` (SSO web UI config)
  - `$HOME/projects/secrets/mongo-express-simple.env` (Basic auth config)
- **Data Volume**: `mongodb_data` (Docker volume)
- **Config Volume**: `mongodb_config` (Docker volume)

## Credentials
- **Admin Username**: admin
- **Admin Password**: [see secrets/mongodb.env]

## Service Database Management

### Adding a Service Database
```bash
cd /home/administrator/projects/mongodb
./add-service-db.sh <service_name> <username> <password>

# Example for ShellHub:
./add-service-db.sh shellhub shellhub ShellHub2025!
```

This creates:
- Database: `<service_name>_db`
- User with full access to that database
- Connection string for the service

### Current Service Databases
1. **shellhub_db**
   - User: shellhub
   - Purpose: ShellHub SSH management

## Web Interface (Mongo Express)

### Deployment Options
1. **With Keycloak SSO** (Production):
   ```bash
   cd /home/administrator/projects/mongodb
   ./deploy-mongo-express.sh
   ```

2. **With Basic Auth** (Testing):
   ```bash
   cd /home/administrator/projects/mongodb
   ./deploy-mongo-express-simple.sh
   ```

### Access
- **URL**: https://mongodb.ai-servicers.com
- **Authentication**: Keycloak SSO (administrators group)
- **Features**:
  - Browse all databases and collections
  - View/edit documents
  - Run queries and aggregations
  - Manage indexes
  - Import/export data

### Keycloak Configuration (Completed)
- **Client ID**: mongodb (changed from mongo-express)
- **Client Secret**: etfiUSlbmE8T5mDMuBHQQmfKKoi9f21r
- **Redirect URI**: https://mongodb.ai-servicers.com/oauth2/callback
- **Groups Scope**: Created and configured in Keycloak
- **Group Mapper**: Added to client for administrators group
- **Status**: ✅ Working with SSO
- **Session Secrets**: Fixed - added ME_CONFIG_SITE_COOKIESECRET and ME_CONFIG_SITE_SESSIONSECRET

## Network Configuration
- **Primary Network**: mongodb-net
- **Connected Networks**: traefik-net (for web UI)
- **Service Integration**: Services connect to mongodb-net

## Common Commands
```bash
# Check status
docker ps | grep mongodb

# View logs
docker logs mongodb --tail 50

# Connect via CLI
docker exec -it mongodb mongosh -u admin -p

# Create service database
cd /home/administrator/projects/mongodb
./add-service-db.sh service_name username password

# Deploy web UI
./deploy-mongo-express.sh
```

## Backup Considerations
- **Critical**: Docker volume `mongodb_data`
- **Important**: Environment files in secrets/
- **Backup Command**:
  ```bash
  docker exec mongodb mongodump --out /data/backup
  ```

## Important Notes

### Network Aliases
- MongoDB container has alias `mongo` for compatibility with some clients
- Added via: `docker network connect --alias mongo mongodb-net mongodb`

### Environment File Requirements
- **Session Secrets Required**: ME_CONFIG_SITE_COOKIESECRET and ME_CONFIG_SITE_SESSIONSECRET
- Watch for line ending issues when credentials get concatenated
- Always use newlines between environment variables
- Check with: `docker exec mongo-express env | grep ME_CONFIG`
- All secrets now externalized to `$HOME/projects/secrets/`

## Troubleshooting

### Session Secret Error (FIXED)
- **Error**: "secret option required for sessions"
- **Cause**: Missing ME_CONFIG_SITE_COOKIESECRET and ME_CONFIG_SITE_SESSIONSECRET
- **Solution**: Added to mongo-express.env and deployment script

### Container won't start
- Check logs: `docker logs mongodb`
- Verify volumes exist: `docker volume ls | grep mongodb`
- Check network: `docker network ls | grep mongodb-net`

### Authentication failures
- Verify credentials in secrets/mongodb.env
- Check database exists: Use add-service-db.sh
- Test connection: `docker exec mongodb mongosh -u user -p`

### Web UI issues
- Check OAuth2 proxy logs: `docker logs mongo-express-auth-proxy`
- Verify Keycloak client configuration
- Test with OAuth debug tool: https://nginx.ai-servicers.com/oauth-debug.html
- Check if groups scope exists in Keycloak

### Mongo Express "mongo not found"
- Fixed by adding network alias `mongo` to mongodb container
- Mongo Express hardcodes looking for "mongo" hostname

## Integration Notes
- All services should use mongodb-net network
- Create separate database per service for isolation
- Use add-service-db.sh script for consistency
- Web UI restricted to administrators group via Keycloak

## Recent Changes (2025-08-25)
- Fixed session secret error for Mongo Express
- Changed all URLs from mongo.ai-servicers.com to mongodb.ai-servicers.com
- Updated Keycloak client ID from mongo-express to mongodb
- Moved all hardcoded credentials to environment files
- Added mongo-express-simple.env for basic auth deployment
- Both SSO and basic auth versions now working

---
*Created: 2025-08-24 by Claude*
*Last Updated: 2025-08-25 - Fixed session secrets and naming consistency*
*Central MongoDB instance for service consolidation*