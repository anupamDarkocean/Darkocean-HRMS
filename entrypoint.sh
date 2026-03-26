#!/bin/bash
set -e

cd /home/frappe/frappe-bench

SITE_NAME="${FRAPPE_SITE_NAME:-site1.local}"

echo "==> Starting Darkocean HRMS (site: $SITE_NAME)"

# ---------------------------------------------------------------------------
# Parse DATABASE_URL into PG* vars if individual vars aren't set
# ---------------------------------------------------------------------------
if [ -z "$PGHOST" ] && [ -n "$DATABASE_URL" ]; then
    eval "$(python3 -c "
from urllib.parse import urlparse, unquote
import shlex, os
u = urlparse(os.environ['DATABASE_URL'])
print(f'export PGHOST={shlex.quote(u.hostname or \"\")}')
print(f'export PGPORT={shlex.quote(str(u.port or 5432))}')
print(f'export PGDATABASE={shlex.quote(u.path.lstrip(\"/\"))}')
print(f'export PGUSER={shlex.quote(unquote(u.username or \"\"))}')
print(f'export PGPASSWORD={shlex.quote(unquote(u.password or \"\"))}')
")"
fi

# ---------------------------------------------------------------------------
# Validate — all must come from Railway, nothing hardcoded
# ---------------------------------------------------------------------------
echo "==> ENV: PGHOST=${PGHOST} PGPORT=${PGPORT} PGDATABASE=${PGDATABASE} PGUSER=${PGUSER}"

if [ -z "$PGHOST" ] || [ -z "$PGUSER" ] || [ -z "$PGPASSWORD" ]; then
    echo "ERROR: Missing PGHOST/PGUSER/PGPASSWORD — connect Railway Postgres plugin" && exit 1
fi
if [ -z "$REDIS_URL" ]; then
    echo "ERROR: Missing REDIS_URL — connect Railway Redis plugin" && exit 1
fi

# ---------------------------------------------------------------------------
# Write configs (reads directly from Railway env, zero defaults)
# ---------------------------------------------------------------------------
python3 -c "
import json, os

config = {
    'db_host':        os.environ['PGHOST'],
    'db_port':        int(os.environ.get('PGPORT', '5432')),
    'db_name':        os.environ.get('PGDATABASE', ''),
    'db_user':        os.environ['PGUSER'],
    'db_password':    os.environ['PGPASSWORD'],
    'db_type':        'postgres',
    'redis_cache':    os.environ['REDIS_URL'] + '/0',
    'redis_queue':    os.environ['REDIS_URL'] + '/1',
    'redis_socketio': os.environ['REDIS_URL'] + '/2',
    'socketio_port':  9000,
    'webserver_port': int(os.environ.get('PORT', '8000')),
}
with open('sites/common_site_config.json', 'w') as f:
    json.dump(config, f, indent=2)
print(f'common_site_config: db_user={config[\"db_user\"]} db_name={config[\"db_name\"]} db_host={config[\"db_host\"]}')
"

# ---------------------------------------------------------------------------
# Wait for Postgres
# ---------------------------------------------------------------------------
echo "==> Waiting for PostgreSQL..."
for i in $(seq 1 30); do
    if python3 -c "
import socket, sys, os
try:
    s = socket.create_connection((os.environ['PGHOST'], int(os.environ.get('PGPORT','5432'))), timeout=3)
    s.close(); sys.exit(0)
except: sys.exit(1)
" 2>/dev/null; then echo "    PostgreSQL ready"; break; fi
    [ "$i" -eq 30 ] && echo "ERROR: PostgreSQL unreachable" && exit 1
    sleep 3
done

# ---------------------------------------------------------------------------
# Wait for Redis
# ---------------------------------------------------------------------------
echo "==> Waiting for Redis..."
for i in $(seq 1 15); do
    if python3 -c "
import socket, sys, os
from urllib.parse import urlparse
u = urlparse(os.environ['REDIS_URL'])
try:
    s = socket.create_connection((u.hostname, u.port or 6379), timeout=3)
    s.close(); sys.exit(0)
except: sys.exit(1)
" 2>/dev/null; then echo "    Redis ready"; break; fi
    [ "$i" -eq 15 ] && echo "ERROR: Redis unreachable" && exit 1
    sleep 2
done

# ---------------------------------------------------------------------------
# Site setup (first run) or credential refresh (subsequent runs)
# ---------------------------------------------------------------------------
if [ -f "sites/${SITE_NAME}/site_config.json" ]; then
    echo "==> Refreshing site_config.json credentials..."
    python3 -c "
import json, os
path = 'sites/${SITE_NAME}/site_config.json'
with open(path) as f: cfg = json.load(f)
cfg['db_host']     = os.environ['PGHOST']
cfg['db_port']     = int(os.environ.get('PGPORT', '5432'))
cfg['db_name']     = os.environ.get('PGDATABASE', '')
cfg['db_user']     = os.environ['PGUSER']
cfg['db_password'] = os.environ['PGPASSWORD']
cfg['db_type']     = 'postgres'
with open(path, 'w') as f: json.dump(cfg, f, indent=2)
print(f'site_config: db_user={cfg[\"db_user\"]} db_name={cfg[\"db_name\"]}')
"
else
    echo "==> First run — creating site: ${SITE_NAME}"
    bench new-site "${SITE_NAME}" \
        --db-type postgres \
        --db-host "${PGHOST}" \
        --db-port "${PGPORT:-5432}" \
        --db-name "${PGDATABASE}" \
        --db-user "${PGUSER}" \
        --db-password "${PGPASSWORD}" \
        --admin-password "${ADMIN_PASSWORD:-admin}" \
        --set-default

    bench --site "${SITE_NAME}" install-app erpnext
    bench --site "${SITE_NAME}" install-app hrms
    echo "==> Site created with erpnext + hrms"
fi

# ---------------------------------------------------------------------------
# Migrate + serve
# ---------------------------------------------------------------------------
echo "==> Running migrations..."
bench --site "${SITE_NAME}" migrate

echo "==> Serving on port ${PORT:-8000}"
exec bench serve --port "${PORT:-8000}" --host 0.0.0.0
