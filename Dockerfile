FROM node:24-slim AS node-donor

FROM python:3.14-slim

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
ENV HOME=/home/frappe
WORKDIR /home/frappe

RUN git config --global user.email "docker@deploy.local" \
    && git config --global user.name "Docker Build"

RUN pip install --user frappe-bench

# ---------------------------------------------------------------------------
# Manual bench init (split into steps for better Railway error visibility)
# ---------------------------------------------------------------------------
RUN mkdir -p /home/frappe/frappe-bench/sites \
             /home/frappe/frappe-bench/apps \
             /home/frappe/frappe-bench/logs \
             /home/frappe/frappe-bench/config/pids \
             /home/frappe/.config/yarn \
             /home/frappe/.cache/yarn

WORKDIR /home/frappe/frappe-bench

# Step 1: Create virtualenv
RUN python3 -m venv env

# Step 2: Upgrade pip/setuptools in venv and install bench
RUN ./env/bin/pip install --upgrade pip setuptools wheel frappe-bench

# Step 3: Clone Frappe
RUN git clone --depth 1 --branch ${FRAPPE_BRANCH} https://github.com/frappe/frappe.git apps/frappe

# Step 4: Install Frappe Python deps
RUN ./env/bin/pip install -e apps/frappe

# Step 4b: Patch frappe/build.py — fix broken shell quoting in get_assets_link()
#   upstream bug: getoutput() sed pipeline breaks on dash, and the error message
#   contains an apostrophe that corrupts log output
RUN python3 <<'PYEOF'
import re, pathlib
p = pathlib.Path("apps/frappe/frappe/build.py")
src = p.read_text()
# Neutralize the getoutput() call that breaks on dash/sh
src = re.sub(r'tag\s*=\s*getoutput\([\s\S]*?\n\s*\)', 'tag = ""', src, count=1)
# Fix apostrophe in error message
src = src.replace("don't exist", "do not exist")
# Add timeout to requests.head() to prevent hangs
src = src.replace("requests.head(url)", "requests.head(url, timeout=5)")
p.write_text(src)
print("Patched frappe/build.py: neutralized getoutput(), fixed quoting")
PYEOF

# Step 5: Install Frappe JS deps (yarn)
RUN cd apps/frappe && yarn install --production

# Step 6: Clone ERPNext
RUN git clone --depth 1 --branch ${FRAPPE_BRANCH} https://github.com/frappe/erpnext.git apps/erpnext

# Step 7: Install ERPNext Python deps
RUN ./env/bin/pip install -e apps/erpnext

# Step 8: Install ERPNext JS deps
RUN cd apps/erpnext && yarn install --production

# Step 9: Generate bench config files
RUN echo '{}' > sites/common_site_config.json \
    && printf "frappe\nerpnext\n" > sites/apps.txt

# Step 10: Generate Procfile (required by bench CLI)
RUN cat > Procfile <<'EOF'
redis_cache: redis-server /etc/redis/redis.conf
redis_queue: redis-server /etc/redis/redis.conf
redis_socketio: redis-server /etc/redis/redis.conf
web: bench serve --port 8000
socketio: node apps/frappe/socketio.js
worker_short: bench worker --queue short
worker_long: bench worker --queue long,default
scheduler: bench scheduler
EOF

# ---------------------------------------------------------------------------
# Copy HRMS app
# ---------------------------------------------------------------------------
COPY --chown=frappe:frappe . apps/hrms/
RUN ./env/bin/pip install --no-cache-dir -e apps/hrms/ \
    && cd apps/hrms && [ -f package.json ] && yarn install --production || true \
    && echo "hrms" >> /home/frappe/frappe-bench/sites/apps.txt

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
COPY --chown=frappe:frappe entrypoint.sh /home/frappe/entrypoint.sh
RUN chmod +x /home/frappe/entrypoint.sh

# ---------------------------------------------------------------------------
# Volume init script (runs as root, then starts supervisord)
# ---------------------------------------------------------------------------
USER root
ENV HOME=/root
COPY init-volume.sh /usr/local/bin/init-volume.sh
RUN chmod +x /usr/local/bin/init-volume.sh

EXPOSE 8000

CMD ["/usr/local/bin/init-volume.sh"]
