#!/bin/bash
################################################################################
# MongoDB Manual Checkpoint/Save All Databases
################################################################################
# Location: /home/administrator/projects/mongodb/manualsavealldb.sh
#
# Purpose: Forces MongoDB to flush all pending writes to disk (fsync)
# This ensures database consistency during backup operations.
#
# Called by: backup scripts before creating tar archives
################################################################################

set -e

echo "=== MongoDB: Forcing fsync to save all data to disk ==="

# Check if MongoDB has authentication
MONGO_ROOT_USER=$(docker exec mongodb env 2>/dev/null | grep MONGO_INITDB_ROOT_USERNAME | cut -d= -f2)
MONGO_ROOT_PASS=$(docker exec mongodb env 2>/dev/null | grep MONGO_INITDB_ROOT_PASSWORD | cut -d= -f2)

# Build mongosh command with auth if needed
if [ -n "$MONGO_ROOT_USER" ] && [ -n "$MONGO_ROOT_PASS" ]; then
    AUTH_PARAMS="-u $MONGO_ROOT_USER -p $MONGO_ROOT_PASS --authenticationDatabase admin"
    echo "Using authenticated connection"
else
    AUTH_PARAMS=""
    echo "Using non-authenticated connection"
fi

# Run fsync command to flush all data to disk
echo "Running fsync command..."
docker exec mongodb mongosh $AUTH_PARAMS --quiet --eval "db.adminCommand({fsync: 1, lock: false})" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ MongoDB fsync completed successfully"
    echo "  All dirty pages have been written to disk"
    echo "  All databases are in consistent state for backup"

    # Show current operation status
    echo ""
    echo "Current operations:"
    docker exec mongodb mongosh $AUTH_PARAMS --quiet --eval "db.currentOp()" 2>/dev/null | head -5
else
    echo "✗ MongoDB fsync failed"
    exit 1
fi

echo ""
echo "=== MongoDB save operation complete ==="
