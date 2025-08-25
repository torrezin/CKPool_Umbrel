#!/bin/bash
set -euo pipefail

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

log "Starting CKPool initialization..."

# Wait for database to be ready with timeout
DB_HOST="db"
DB_PORT="5432"
DB_USER="ckpool"
DB_NAME="ckpool"
TIMEOUT=60
COUNTER=0

log "Waiting for PostgreSQL database to be ready..."
while ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; do
    if [ $COUNTER -ge $TIMEOUT ]; then
        log "ERROR: Database connection timeout after ${TIMEOUT} seconds"
        exit 1
    fi
    log "Database not ready, waiting... (${COUNTER}s/${TIMEOUT}s)"
    sleep 2
    COUNTER=$((COUNTER + 2))
done

log "Database is ready!"

# Replace environment variables in config
if [ -n "${POSTGRES_PASSWORD:-}" ]; then
    sed -i "s/ENV:POSTGRES_PASSWORD/${POSTGRES_PASSWORD}/g" /etc/ckpool/ckpool.conf
    log "Updated database password in configuration"
fi

# Initialize database schema if needed
log "Checking database schema..."
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'users'" >/dev/null 2>&1; then
    log "Initializing database schema..."
    
    # Create basic tables (adjust based on CKPool's actual schema requirements)
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS workers (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    worker_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS shares (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    worker_id INTEGER REFERENCES workers(id),
    difficulty FLOAT NOT NULL,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_shares_user_id ON shares(user_id);
CREATE INDEX IF NOT EXISTS idx_shares_submitted_at ON shares(submitted_at);
EOF
    
    log "Database schema initialized successfully"
else
    log "Database schema already exists"
fi

# Ensure log directory exists and has correct permissions
mkdir -p /var/log/ckpool
touch /var/log/ckpool/ckpool.log

# Validate configuration file
log "Validating configuration file..."
if [ ! -f "/etc/ckpool/ckpool.conf" ]; then
    log "ERROR: Configuration file not found at /etc/ckpool/ckpool.conf"
    exit 1
fi

# Test configuration syntax (basic JSON validation)
if ! python3 -c "import json; json.load(open('/etc/ckpool/ckpool.conf'))" 2>/dev/null; then
    log "ERROR: Invalid JSON in configuration file"
    exit 1
fi

log "Configuration file validated successfully"

# Start CKPool with proper error handling
log "Starting CKPool server..."
exec /usr/local/bin/ckpool -c "${CKPOOL_CONFIG:-/etc/ckpool/ckpool.conf}"