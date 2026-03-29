#!/bin/bash
set -e

cd /home/frappe/frappe-bench

SITE_NAME="${FRAPPE_SITE_NAME:-site1.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"
PORT="${PORT:-8000}"

# ---------------------------------------------------------------------------
# 0. Start a temporary health-check server so Railway doesn't kill us
#    while bench build / migrate are still running
# ---------------------------------------------------------------------------
echo "==> Starting temporary health-check server on port ${PORT}..."
python3 -c "
import http.server, threading
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'Starting up...')
    def log_message(self, *a): pass
s = http.server.HTTPServer(('0.0.0.0', ${PORT}), H)
threading.Thread(target=s.serve_forever, daemon=True).start()
import time; time.sleep(999999)
" &
HEALTH_PID=$!
echo "    Health-check PID: ${HEALTH_PID}"

# ---------------------------------------------------------------------------
# 1. Wait for MariaDB (auth-free check)
# ---------------------------------------------------------------------------
echo "==> Waiting for MariaDB..."
for i in $(seq 1 45); do
    if mysqladmin ping -h 127.0.0.1 --silent 2>/dev/null; then
        echo "    MariaDB ready"
        break
    fi
    [ "$i" -eq 45 ] && echo "ERROR: MariaDB not ready after 90s" && exit 1
    sleep 2
done

# Ensure root can connect via TCP — reset password if needed
if ! mariadb -u root -p"${DB_ROOT_PASSWORD}" -h 127.0.0.1 -e "SELECT 1" &>/dev/null; then
    echo "    TCP auth failed, resetting root password via socket..."
    mariadb --socket=/run/mysqld/mysqld.sock -u root <<-EOSQL
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
EOSQL
    echo "    Root password reset OK"
fi
echo "    MariaDB root auth OK"

# ---------------------------------------------------------------------------
# 2. Wait for Redis
# ---------------------------------------------------------------------------
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
# 3. Write common_site_config.json (every boot)
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
# 4. Enforce MariaDB config in existing site_config.json (fix stale PG values)
# ---------------------------------------------------------------------------
SITE_CONFIG="sites/${SITE_NAME}/site_config.json"

if [ -f "$SITE_CONFIG" ]; then
    echo "==> Enforcing MariaDB config in site_config.json..."
    python3 -c "
import json

path = '${SITE_CONFIG}'
with open(path) as f:
    cfg = json.load(f)

old_type = cfg.get('db_type', 'unknown')
old_host = cfg.get('db_host', 'unknown')

cfg['db_type'] = 'mariadb'
cfg['db_host'] = '127.0.0.1'
cfg['db_port'] = 3306

# Remove stale PostgreSQL-only keys if migrating from PG
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
# 5. Create site on first run
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
# 6. Debug: print final configs
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
# 7. Ensure Frappe can route requests from any Host header
# ---------------------------------------------------------------------------
# Railway (and other PaaS) send requests with the public domain as Host.
# Tell Frappe which site to serve regardless of the incoming Host header.
bench use "${SITE_NAME}" 2>/dev/null || true

# If RAILWAY_PUBLIC_DOMAIN is set, add it as a domain alias for the site
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    echo "==> Adding Railway domain alias: ${RAILWAY_PUBLIC_DOMAIN}"
    bench --site "${SITE_NAME}" add-domain "${RAILWAY_PUBLIC_DOMAIN}" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 8. Build assets, migrate, serve
# ---------------------------------------------------------------------------
echo "==> Building assets..."
bench build

echo "==> Running migrations..."
bench --site "${SITE_NAME}" migrate

bench --site "${SITE_NAME}" enable-scheduler

# Kill the temporary health-check server
echo "==> Stopping health-check server (PID ${HEALTH_PID})..."
kill "${HEALTH_PID}" 2>/dev/null || true
sleep 1

echo "==> Serving on port ${PORT}"
exec bench serve --port "${PORT}" --host 0.0.0.0
