FROM node:20-slim AS node-donor

FROM python:3.13-slim

ARG FRAPPE_BRANCH=version-16

# ---------------------------------------------------------------------------
# System deps: MariaDB, Redis, build tools, supervisord
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    git \
    curl \
    libssl-dev \
    libffi-dev \
    libjpeg-dev \
    zlib1g-dev \
    libfreetype6-dev \
    libwebp-dev \
    mariadb-server \
    mariadb-client \
    libmariadb-dev \
    redis-server \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Node.js + yarn
# ---------------------------------------------------------------------------
COPY --from=node-donor /usr/local/bin/node /usr/local/bin/node
COPY --from=node-donor /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm install -g yarn

# ---------------------------------------------------------------------------
# Persistent data dirs (Railway volume mounts to /data)
# ---------------------------------------------------------------------------
RUN mkdir -p /data/mariadb /data/redis /data/sites /run/mysqld \
    && chown mysql:mysql /data/mariadb /run/mysqld \
    && chown -R redis:redis /data/redis

# ---------------------------------------------------------------------------
# Redis config (daemonize off for supervisord, persist to /data)
# ---------------------------------------------------------------------------
RUN sed -i 's/^daemonize yes/daemonize no/' /etc/redis/redis.conf || true \
    && echo "dir /data/redis" >> /etc/redis/redis.conf \
    && echo "appendonly yes" >> /etc/redis/redis.conf

# ---------------------------------------------------------------------------
# Non-root user for bench
# ---------------------------------------------------------------------------
RUN useradd -ms /bin/bash frappe \
    && mkdir -p /var/log/supervisor \
    && chown -R frappe:frappe /var/log/supervisor

ENV PATH="/home/frappe/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Supervisord config
# ---------------------------------------------------------------------------
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ---------------------------------------------------------------------------
# Install bench + frappe + erpnext as frappe user
# ---------------------------------------------------------------------------
USER frappe
WORKDIR /home/frappe

RUN git config --global user.email "docker@deploy.local" \
    && git config --global user.name "Docker Build"

RUN pip install --user frappe-bench

RUN bench init /home/frappe/frappe-bench \
    --frappe-branch ${FRAPPE_BRANCH} \
    --skip-redis-config-generation \
    --skip-assets \
    --verbose

WORKDIR /home/frappe/frappe-bench

RUN bench get-app erpnext --branch ${FRAPPE_BRANCH} --skip-assets

# ---------------------------------------------------------------------------
# Copy HRMS app
# ---------------------------------------------------------------------------
COPY --chown=frappe:frappe . apps/hrms/
RUN ./env/bin/pip install --no-cache-dir -e apps/hrms/

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
COPY --chown=frappe:frappe entrypoint.sh /home/frappe/entrypoint.sh
RUN chmod +x /home/frappe/entrypoint.sh

# ---------------------------------------------------------------------------
# Volume init script (runs as root, then starts supervisord)
# ---------------------------------------------------------------------------
USER root
COPY init-volume.sh /usr/local/bin/init-volume.sh
RUN chmod +x /usr/local/bin/init-volume.sh

EXPOSE 8000

VOLUME ["/data"]
CMD ["/usr/local/bin/init-volume.sh"]
