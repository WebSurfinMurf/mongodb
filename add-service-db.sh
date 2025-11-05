#!/bin/bash
# Usage: ./add-service-db.sh <service_name> <username> <password>

if [ $# -ne 3 ]; then
    echo "Usage: $0 <service_name> <username> <password>"
    echo "Example: $0 shellhub shellhub_user MySecurePass123"
    exit 1
fi

SERVICE_NAME=$1
DB_USER=$2
DB_PASSWORD=$3
DB_NAME="${SERVICE_NAME}_db"

source $HOME/projects/secrets/mongodb.env

echo "Creating database '$DB_NAME' with user '$DB_USER'..."

docker exec mongodb mongosh \
  --username "$MONGO_INITDB_ROOT_USERNAME" \
  --password "$MONGO_INITDB_ROOT_PASSWORD" \
  --authenticationDatabase admin \
  --eval "
    use $DB_NAME;
    db.createUser({
      user: '$DB_USER',
      pwd: '$DB_PASSWORD',
      roles: [
        { role: 'dbOwner', db: '$DB_NAME' },
        { role: 'readWrite', db: '$DB_NAME' }
      ]
    });
    print('Database $DB_NAME created with user $DB_USER');
  "

echo ""
echo "Connection string for $SERVICE_NAME:"
echo "mongodb://$DB_USER:$DB_PASSWORD@mongodb:27017/$DB_NAME?authSource=$DB_NAME"
