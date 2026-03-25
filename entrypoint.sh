#!/bin/bash
set -e

BENCH_DIR="/home/frappe/frappe-bench"
cd "$BENCH_DIR"

SITE_NAME="${FRAPPE_SITE_NAME:-site1.local}"

echo "==> Starting Darkocean HRMS (site: $SITE_NAME)"

# ---------------------------------------------------------------------------
# Resolve database connection
# Railway sets PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD for its Postgres
# plugin. Fall back to parsing DATABASE_URL if the individual vars are absent.
# ---------------------------------------------------------------------------
if [ -z "$PGHOST" ] && [ -n "$DATABASE_URL" ]; then
    export PGHOST=$(python3 -c "from urllib.parse import urlparse; u=urlparse('$DATABASE_URL'); print(u.hostname)")
    export PGPORT=$(python3 -c "from urllib.parse import urlparse; u=urlparse('$DATABASE_URL'); print(u.port or 5432)")
    export PGDATABASE=$(python3 -c "from urllib.parse import urlparse; u=urlparse('$DATABASE_URL'); print(u.path.lstrip('/'))")
    export PGUSER=$(python3 -c "from urllib.parse import urlparse; u=urlparse('$DATABASE_URL'); print(u.username)")
    export PGPASSWORD=$(python3 -c "from urllib.parse import urlparse; u=urlparse('$DATABASE_URL'); print(u.password)")
fi

DB_HOST="${PGHOST:-localhost}"
DB_PORT="${PGPORT:-5432}"
DB_NAME="${PGDATABASE:-hrms}"
DB_PASSWORD="${PGPASSWORD}"

# ---------------------------------------------------------------------------
# Resolve Redis URL
# Railway sets REDIS_URL for its Redis plugin.
# ---------------------------------------------------------------------------
REDIS_URL="${REDIS_URL:-redis://localhost:6379}"

# ---------------------------------------------------------------------------
# Write sites/common_site_config.json so bench can find Redis and the DB host
# ---------------------------------------------------------------------------
python3 - <<EOF
import json

config = {
    "db_host": "${DB_HOST}",
    "db_port": int("${DB_PORT}"),
    "db_name": "${DB_NAME}",
    "db_password": "${DB_PASSWORD}",
    "db_type": "postgres",
    "redis_cache":    "${REDIS_URL}/0",
    "redis_queue":    "${REDIS_URL}/1",
    "redis_socketio": "${REDIS_URL}/2",
    "socketio_port":  9000,
    "webserver_port": int("${PORT:-8000}"),
}
with open("sites/common_site_config.json", "w") as f:
    json.dump(config, f, indent=2)
print("common_site_config.json written")
EOF

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
# First-run site initialisation
# NOTE: Railway volumes should be mounted at /home/frappe/frappe-bench/sites
# to persist data across deploys. Without a volume every restart re-creates
# the site and data is lost.
# ---------------------------------------------------------------------------
if [ -f "sites/${SITE_NAME}/site_config.json" ]; then
    # Site exists from a prior deploy — refresh DB credentials in case
    # Railway rotated them or the Postgres service was recreated.
    echo "==> Updating site DB credentials from environment..."
    python3 - <<PYEOF
import json, os

site_config_path = "sites/${SITE_NAME}/site_config.json"
with open(site_config_path) as f:
    cfg = json.load(f)

cfg["db_host"] = "${DB_HOST}"
cfg["db_port"] = int("${DB_PORT}")
cfg["db_name"] = "${DB_NAME}"
cfg["db_password"] = "${DB_PASSWORD}"
cfg["db_type"] = "postgres"

with open(site_config_path, "w") as f:
    json.dump(cfg, f, indent=2)
print("site_config.json updated with current credentials")
PYEOF
else
    echo "==> Creating site: ${SITE_NAME}"
    bench new-site "${SITE_NAME}" \
        --db-type postgres \
        --db-host "${DB_HOST}" \
        --db-port "${DB_PORT}" \
        --db-name "${DB_NAME}" \
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
