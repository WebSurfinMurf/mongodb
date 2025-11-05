# MongoDB Central Instance

## Overview
Central MongoDB database server with web management UI protected by Keycloak SSO.

## Services
- **mongodb**: MongoDB 6.0 database server
- **mongo-express**: Web-based database management UI
- **mongo-express-auth-proxy**: OAuth2 proxy for SSO authentication

## Deployment
```bash
cd /home/administrator/projects/mongodb
./deploy.sh
```

## Access
- **Web UI**: https://mongodb.ai-servicers.com (requires Keycloak SSO)
- **Internal**: mongodb://mongodb:27017
- **External**: mongodb://localhost:27017

## Configuration
- **Secrets**: `$HOME/projects/secrets/mongo-express.env`
- **Networks**: mongodb-net, traefik-net, keycloak-net
- **Volumes**: mongodb_data, mongodb_config

## Service Databases
Current databases:
- shellhub_db (ShellHub SSH management)

### Adding a Service Database
Use the provided script to create new service databases:
```bash
cd /home/administrator/projects/mongodb
./add-service-db.sh <service_name> <username> <password>
```

Example:
```bash
./add-service-db.sh myapp myapp_user SecurePass123
```

## Common Commands
```bash
# View logs
docker logs mongodb -f

# Connect via mongosh
docker exec -it mongodb mongosh -u admin

# List databases
docker exec mongodb mongosh -u admin -p --authenticationDatabase admin --eval "db.adminCommand('listDatabases')"

# Check container status
docker ps | grep mongo
```

## Networks
- **mongodb-net**: Database access (internal only)
- **traefik-net**: Web UI routing
- **keycloak-net**: SSO authentication

## Volumes
- **mongodb_data**: Database files
- **mongodb_config**: Configuration files

## Security
- Admin credentials stored in secrets file
- Web UI protected by Keycloak SSO
- Administrators group required for access
- Database isolated on mongodb-net

## Health Checks
- MongoDB: `mongosh --eval "db.adminCommand('ping')"`
- Container includes automatic health monitoring

---
*Standardized: 2025-09-30*
*Part of Phase 2: Database Layer*
