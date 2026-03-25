FROM python:3.10-slim

ARG FRAPPE_BRANCH=version-17
ARG NODE_VERSION=18

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
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Node.js + yarn
# ---------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

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
# Initialise bench with Frappe v17
# --skip-assets: skip frappe's own JS/CSS build (we build hrms assets later)
# Layers below are cached until FRAPPE_BRANCH changes.
# ---------------------------------------------------------------------------
RUN bench init /home/frappe/frappe-bench \
    --frappe-branch ${FRAPPE_BRANCH} \
    --skip-redis-config-generation \
    --verbose

WORKDIR /home/frappe/frappe-bench

# ---------------------------------------------------------------------------
# Get ERPNext v17 (required by hrms)
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
