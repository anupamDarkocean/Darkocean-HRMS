#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# This script runs as ROOT before supervisord starts.
# It initializes the /data volume and bootstraps MariaDB auth.
# ---------------------------------------------------------------------------

DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"
DB_INIT_FLAG="/data/.db_initialized"

# ---------------------------------------------------------------------------
# 1. Initialize MariaDB data dir on volume if empty
# ---------------------------------------------------------------------------
if [ ! -d "/data/mariadb/mysql" ]; then
    echo "==> Initializing MariaDB data directory on volume..."
    mysql_install_db --user=mysql --datadir=/data/mariadb
fi
chown -R mysql:mysql /data/mariadb /run/mysqld

# ---------------------------------------------------------------------------
# 2. Redis data dir
# ---------------------------------------------------------------------------
mkdir -p /data/redis
chown -R redis:redis /data/redis

# ---------------------------------------------------------------------------
# 3. Frappe sites — persist on volume
# ---------------------------------------------------------------------------
mkdir -p /data/sites
BENCH_SITES="/home/frappe/frappe-bench/sites"

if [ ! -f "/data/sites/.initialized" ]; then
    echo "==> Copying default sites to volume..."
    cp -a "${BENCH_SITES}/." /data/sites/
    touch /data/sites/.initialized
fi

rm -rf "${BENCH_SITES}"
ln -sf /data/sites "${BENCH_SITES}"
chown -h frappe:frappe "${BENCH_SITES}"

# ---------------------------------------------------------------------------
# 3b. Logs dir on volume — Frappe resolves ../logs from /data/sites → /data/logs
# ---------------------------------------------------------------------------
mkdir -p /data/logs
chown frappe:frappe /data/logs
BENCH_LOGS="/home/frappe/frappe-bench/logs"
rm -rf "${BENCH_LOGS}"
ln -sf /data/logs "${BENCH_LOGS}"
chown -h frappe:frappe "${BENCH_LOGS}"

# ---------------------------------------------------------------------------
# 4. Bootstrap MariaDB root password (first run only)
#    We start MariaDB temporarily, set root password for TCP access,
#    then stop it. Supervisord will start it properly afterward.
# ---------------------------------------------------------------------------
if [ ! -f "$DB_INIT_FLAG" ]; then
    echo "==> First run: bootstrapping MariaDB root auth..."

    # Start MariaDB temporarily in background
    /usr/sbin/mariadbd --user=mysql --datadir=/data/mariadb \
        --socket=/run/mysqld/mysqld.sock \
        --pid-file=/run/mysqld/mysqld.pid &
    MARIADB_PID=$!

    # Wait for it to be ready
    for i in $(seq 1 30); do
        if mysqladmin ping --socket=/run/mysqld/mysqld.sock --silent 2>/dev/null; then
            echo "    MariaDB temp instance ready"
            break
        fi
        [ "$i" -eq 30 ] && echo "ERROR: MariaDB temp instance not ready" && exit 1
        sleep 2
    done

    # Set root password and create root@127.0.0.1 for TCP access
    # (socket auth lets us connect as OS root without a password)
    mariadb --socket=/run/mysqld/mysqld.sock -u root <<-EOSQL
        -- Set password for socket connections
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        -- Create root user for TCP connections (how Frappe connects)
        CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
EOSQL

    echo "    MariaDB root auth configured"

    # Stop temporary instance cleanly
    mysqladmin --socket=/run/mysqld/mysqld.sock -u root -p"${DB_ROOT_PASSWORD}" shutdown 2>/dev/null || kill "$MARIADB_PID"
    wait "$MARIADB_PID" 2>/dev/null || true

    touch "$DB_INIT_FLAG"
    echo "    MariaDB bootstrap complete"
fi

echo "==> Volume initialized, starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
