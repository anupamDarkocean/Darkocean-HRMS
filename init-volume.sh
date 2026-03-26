#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# Initialize /data volume directories (runs as root before services start)
# ---------------------------------------------------------------------------

# MariaDB data
if [ ! -d "/data/mariadb/mysql" ]; then
    echo "==> Initializing MariaDB data directory on volume..."
    mysql_install_db --user=mysql --datadir=/data/mariadb
fi
chown -R mysql:mysql /data/mariadb /run/mysqld

# Redis data
mkdir -p /data/redis
chown -R redis:redis /data/redis

# Frappe sites — persist on volume
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

echo "==> Volume initialized, starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
