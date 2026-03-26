#!/bin/bash
set -e

cd /home/frappe/frappe-bench

SITE_NAME="${FRAPPE_SITE_NAME:-site1.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"
PORT="${PORT:-8000}"
DB_INIT_FLAG="/data/.db_initialized"

echo "==> Waiting for MariaDB..."
for i in $(seq 1 30); do
    if mariadb -u root -e "SELECT 1" &>/dev/null; then
        echo "    MariaDB ready"
        break
    fi
    [ "$i" -eq 30 ] && echo "ERROR: MariaDB not ready" && exit 1
    sleep 2
done

echo "==> Waiting for Redis..."
for i in $(seq 1 15); do
    if redis-cli ping &>/dev/null; then
        echo "    Redis ready"
        break
    fi
    [ "$i" -eq 15 ] && echo "ERROR: Redis not ready" && exit 1
    sleep 2
done

# ---------------------------------------------------------------------------
# Set up MariaDB root password on first run
# ---------------------------------------------------------------------------
if [ ! -f "$DB_INIT_FLAG" ]; then
    echo "==> Initializing MariaDB users..."
    mariadb -u root <<-EOSQL
        FLUSH PRIVILEGES;
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        FLUSH PRIVILEGES;
EOSQL
    touch "$DB_INIT_FLAG"
fi

# ---------------------------------------------------------------------------
# Configure bench to use local MariaDB + Redis (every boot)
# ---------------------------------------------------------------------------
python3 -c "
import json

config = {
    'db_host':        '127.0.0.1',
    'db_port':        3306,
    'db_type':        'mariadb',
    'redis_cache':    'redis://127.0.0.1:6379/0',
    'redis_queue':    'redis://127.0.0.1:6379/1',
    'redis_socketio': 'redis://127.0.0.1:6379/2',
    'socketio_port':  9000,
    'webserver_port': ${PORT},
}
with open('sites/common_site_config.json', 'w') as f:
    json.dump(config, f, indent=2)
print('common_site_config written')
"

# ---------------------------------------------------------------------------
# Enforce MariaDB config in site_config.json (fix stale PG values)
# ---------------------------------------------------------------------------
SITE_CONFIG="sites/${SITE_NAME}/site_config.json"

if [ -f "$SITE_CONFIG" ]; then
    echo "==> Enforcing MariaDB config in site_config.json..."
    python3 -c "
import json, sys

path = '${SITE_CONFIG}'
with open(path) as f:
    cfg = json.load(f)

old_type = cfg.get('db_type', 'unknown')
old_host = cfg.get('db_host', 'unknown')

# Overwrite DB connection fields to local MariaDB
cfg['db_type']     = 'mariadb'
cfg['db_host']     = '127.0.0.1'
cfg['db_port']     = 3306

# Remove stale PostgreSQL-only keys if present
for key in ['db_user', 'db_password', 'db_name']:
    if key in cfg and old_type == 'postgres':
        print(f'  Removing stale PG key: {key}={cfg[key]}')
        del cfg[key]

with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)

if old_type != 'mariadb' or old_host != '127.0.0.1':
    print(f'  FIXED: was db_type={old_type}, db_host={old_host} -> mariadb @ 127.0.0.1')
else:
    print(f'  OK: already mariadb @ 127.0.0.1')
"
fi

# ---------------------------------------------------------------------------
# Create site on first run
# ---------------------------------------------------------------------------
if [ ! -f "$SITE_CONFIG" ]; then
    echo "==> First run — creating site: ${SITE_NAME}"
    bench new-site "${SITE_NAME}" \
        --db-type mariadb \
        --db-host 127.0.0.1 \
        --mariadb-root-password "${DB_ROOT_PASSWORD}" \
        --admin-password "${ADMIN_PASSWORD}" \
        --set-default \
        --no-mariadb-socket

    bench --site "${SITE_NAME}" install-app erpnext
    bench --site "${SITE_NAME}" install-app hrms
    echo "==> Site created with erpnext + hrms"
fi

# ---------------------------------------------------------------------------
# Debug: print final configs before migrate
# ---------------------------------------------------------------------------
echo ""
echo "========== common_site_config.json =========="
cat sites/common_site_config.json
echo ""
echo "========== ${SITE_NAME}/site_config.json =========="
cat "sites/${SITE_NAME}/site_config.json"
echo ""
echo "=============================================="
echo ""

# ---------------------------------------------------------------------------
# Build assets, migrate, serve
# ---------------------------------------------------------------------------
echo "==> Building assets..."
bench build

echo "==> Running migrations..."
bench --site "${SITE_NAME}" migrate

bench --site "${SITE_NAME}" enable-scheduler

echo "==> Serving on port ${PORT}"
exec bench serve --port "${PORT}" --host 0.0.0.0
