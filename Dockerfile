FROM node:20-slim AS node-donor

FROM python:3.11-slim

ARG FRAPPE_BRANCH=develop

# ---------------------------------------------------------------------------
# System dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    libssl-dev \
    libjpeg-dev \
    zlib1g-dev \
    libffi-dev \
    libpq-dev \
    postgresql-client \
    redis-tools \
    cron \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Node.js + yarn  (copied from official node image — avoids deprecated NodeSource)
# ---------------------------------------------------------------------------
COPY --from=node-donor /usr/local/bin/node /usr/local/bin/node
COPY --from=node-donor /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm install -g yarn

# ---------------------------------------------------------------------------
# Non-root user (bench refuses to run as root)
# ---------------------------------------------------------------------------
RUN useradd -ms /bin/bash frappe
USER frappe
WORKDIR /home/frappe

ENV PATH="/home/frappe/.local/bin:$PATH"

# git needs an identity for internal operations during bench init
RUN git config --global user.email "docker@deploy.local" \
    && git config --global user.name "Docker Build"

# ---------------------------------------------------------------------------
# Install bench CLI
# ---------------------------------------------------------------------------
RUN pip install --user frappe-bench

# ---------------------------------------------------------------------------
# Initialise bench with Frappe (develop = v17-dev)
# Layers below are cached until FRAPPE_BRANCH changes.
# ---------------------------------------------------------------------------
RUN bench init /home/frappe/frappe-bench \
    --frappe-branch ${FRAPPE_BRANCH} \
    --skip-redis-config-generation \
    --skip-assets \
    --verbose

WORKDIR /home/frappe/frappe-bench

# ---------------------------------------------------------------------------
# Get ERPNext (develop = v17-dev, required by hrms)
# Separate layer — cached independently of our app code.
# ---------------------------------------------------------------------------
RUN bench get-app erpnext \
    --branch ${FRAPPE_BRANCH} \
    --skip-assets

# ---------------------------------------------------------------------------
# Copy entrypoint before the app so it has its own cached layer
# ---------------------------------------------------------------------------
COPY --chown=frappe:frappe entrypoint.sh /home/frappe/entrypoint.sh
RUN chmod +x /home/frappe/entrypoint.sh

# ---------------------------------------------------------------------------
# Copy hrms app source (cache busted on every code change)
# ---------------------------------------------------------------------------
COPY --chown=frappe:frappe . apps/hrms/

# Install hrms Python package into the bench virtualenv
RUN ./env/bin/pip install --no-cache-dir -e apps/hrms/

# Build frontend (Vite + roster)
RUN cd apps/hrms && yarn install --frozen-lockfile && yarn build

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
EXPOSE 8000

# Mount /home/frappe/frappe-bench/sites as a Railway persistent volume
# to preserve site data across deploys.
CMD ["/home/frappe/entrypoint.sh"]
