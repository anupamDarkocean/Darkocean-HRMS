#!/bin/bash
set -e

BENCH_DIR="/home/frappe/frappe-bench"
cd "$BENCH_DIR"

SITE_NAME="${FRAPPE_SITE_NAME:-site1.local}"

echo "==> Starting Darkocean HRMS (site: $SITE_NAME)"

# ---------------------------------------------------------------------------
# Resolve database connection
# Railway's Postgres plugin injects PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD.
# Fall back to DB_HOST/DB_NAME/etc. (manual vars), then to parsing DATABASE_URL.
# ---------------------------------------------------------------------------
if [ -z "$PGHOST" ] && [ -n "$DATABASE_URL" ]; then
    eval "$(python3 -c "
from urllib.parse import urlparse, unquote
import shlex, os
u = urlparse(os.environ['DATABASE_URL'])
print(f'export PGHOST={shlex.quote(u.hostname or \"localhost\")}')
print(f'export PGPORT={shlex.quote(str(u.port or 5432))}')
print(f'export PGDATABASE={shlex.quote(u.path.lstrip(\"/\"))}')
print(f'export PGUSER={shlex.quote(unquote(u.username or \"postgres\"))}')
print(f'export PGPASSWORD={shlex.quote(unquote(u.password or \"\"))}')
")"
fi

# Support both Railway plugin vars (PG*) and manual vars (DB_*)
export PGHOST="${PGHOST:-${DB_HOST:-localhost}}"
export PGPORT="${PGPORT:-${DB_PORT:-5432}}"
export PGDATABASE="${PGDATABASE:-${DB_NAME:-hrms}}"
export PGUSER="${PGUSER:-${DB_USER:-postgres}}"
export PGPASSWORD="${PGPASSWORD:-${DB_PASSWORD}}"

DB_HOST="$PGHOST"
DB_PORT="$PGPORT"
DB_NAME="$PGDATABASE"
DB_USER="$PGUSER"
DB_PASSWORD="$PGPASSWORD"

echo "==> DB connection: host=${DB_HOST} port=${DB_PORT} db=${DB_NAME} user=${DB_USER}"

# ---------------------------------------------------------------------------
# Resolve Redis URL
# Railway's Redis plugin injects REDIS_URL on the internal network.
# ---------------------------------------------------------------------------
REDIS_URL="${REDIS_URL:-redis://localhost:6379}"

echo "==> Redis URL: ${REDIS_URL}"

# ---------------------------------------------------------------------------
# Write sites/common_site_config.json
# Uses os.environ to avoid shell interpolation mangling passwords.
# ---------------------------------------------------------------------------
python3 -c "
import json, os

config = {
    'db_host':        os.environ.get('PGHOST', 'localhost'),
    'db_port':        int(os.environ.get('PGPORT', '5432')),
    'db_name':        os.environ.get('PGDATABASE', 'hrms'),
    'db_user':        os.environ.get('PGUSER', 'postgres'),
    'db_password':    os.environ.get('PGPASSWORD', ''),
    'db_type':        'postgres',
    'redis_cache':    os.environ.get('REDIS_URL', 'redis://localhost:6379') + '/0',
    'redis_queue':    os.environ.get('REDIS_URL', 'redis://localhost:6379') + '/1',
    'redis_socketio': os.environ.get('REDIS_URL', 'redis://localhost:6379') + '/2',
    'socketio_port':  9000,
    'webserver_port': int(os.environ.get('PORT', '8000')),
}
with open('sites/common_site_config.json', 'w') as f:
    json.dump(config, f, indent=2)
print('common_site_config.json written')
"

# ---------------------------------------------------------------------------
# Wait for PostgreSQL
# ---------------------------------------------------------------------------
echo "==> Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
for i in $(seq 1 30); do
    if python3 -c "
import socket, sys
try:
    s = socket.create_connection(('${DB_HOST}', ${DB_PORT}), timeout=3)
    s.close()
    sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
        echo "    PostgreSQL is ready"
        break
    fi
    [ "$i" -eq 30 ] && echo "ERROR: PostgreSQL not reachable after 30 attempts" && exit 1
    echo "    Attempt $i/30 — retrying in 3s..."
    sleep 3
done

# ---------------------------------------------------------------------------
# Wait for Redis (required — bench migrate needs cache)
# ---------------------------------------------------------------------------
echo "==> Waiting for Redis at ${REDIS_URL}..."
for i in $(seq 1 15); do
    if python3 -c "
import socket, sys, os
from urllib.parse import urlparse
u = urlparse(os.environ.get('REDIS_URL', 'redis://localhost:6379'))
try:
    s = socket.create_connection((u.hostname, u.port or 6379), timeout=3)
    s.close()
    sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
        echo "    Redis is ready"
        break
    fi
    [ "$i" -eq 15 ] && echo "ERROR: Redis not reachable after 15 attempts — aborting (bench migrate requires Redis)" && exit 1
    echo "    Attempt $i/15 — retrying in 2s..."
    sleep 2
done

# ---------------------------------------------------------------------------
# First-run site initialisation / credential refresh
# ---------------------------------------------------------------------------
if [ -f "sites/${SITE_NAME}/site_config.json" ]; then
    # Site exists — refresh credentials from env (handles Railway rotation)
    echo "==> Updating site DB credentials from environment..."
    python3 -c "
import json, os

path = 'sites/${SITE_NAME}/site_config.json'
with open(path) as f:
    cfg = json.load(f)

cfg['db_host']     = os.environ.get('PGHOST', 'localhost')
cfg['db_port']     = int(os.environ.get('PGPORT', '5432'))
cfg['db_name']     = os.environ.get('PGDATABASE', 'hrms')
cfg['db_user']     = os.environ.get('PGUSER', 'postgres')
cfg['db_password'] = os.environ.get('PGPASSWORD', '')
cfg['db_type']     = 'postgres'

with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
print('site_config.json updated with current credentials')
"
else
    echo "==> Creating site: ${SITE_NAME}"
    bench new-site "${SITE_NAME}" \
        --db-type postgres \
        --db-host "${DB_HOST}" \
        --db-port "${DB_PORT}" \
        --db-name "${DB_NAME}" \
        --db-user "${DB_USER}" \
        --db-password "${DB_PASSWORD}" \
        --admin-password "${ADMIN_PASSWORD:-admin}" \
        --set-default

    echo "==> Installing ERPNext..."
    bench --site "${SITE_NAME}" install-app erpnext

    echo "==> Installing HRMS..."
    bench --site "${SITE_NAME}" install-app hrms

    echo "==> Site initialised"
fi

# ---------------------------------------------------------------------------
# Migrations (safe to run on every start)
# ---------------------------------------------------------------------------
echo "==> Running migrations..."
bench --site "${SITE_NAME}" migrate

# ---------------------------------------------------------------------------
# Start server
# ---------------------------------------------------------------------------
echo "==> Starting server on port ${PORT:-8000}..."
exec bench serve --port "${PORT:-8000}" --host 0.0.0.0
