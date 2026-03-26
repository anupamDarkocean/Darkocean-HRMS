FROM node:20-slim AS node-donor

FROM python:3.11-slim

ARG FRAPPE_BRANCH=develop

# ---------------------------------------------------------------------------
# System deps (only what bench init + psycopg2 + Pillow need to compile)
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    git \
    curl \
    libssl-dev \
    libffi-dev \
    libpq-dev \
    postgresql-client \
    libjpeg-dev \
    zlib1g-dev \
    libfreetype6-dev \
    libwebp-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Node.js + yarn (from official node image)
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

RUN git config --global user.email "docker@deploy.local" \
    && git config --global user.name "Docker Build"

# ---------------------------------------------------------------------------
# Bench + Frappe + ERPNext + HRMS — all built at image time
# ---------------------------------------------------------------------------
RUN pip install --user frappe-bench

RUN bench init /home/frappe/frappe-bench \
    --frappe-branch ${FRAPPE_BRANCH} \
    --skip-redis-config-generation \
    --skip-assets \
    --verbose

WORKDIR /home/frappe/frappe-bench

RUN bench get-app erpnext --branch ${FRAPPE_BRANCH} --skip-assets

COPY --chown=frappe:frappe entrypoint.sh /home/frappe/entrypoint.sh
RUN chmod +x /home/frappe/entrypoint.sh

COPY --chown=frappe:frappe . apps/hrms/
RUN ./env/bin/pip install --no-cache-dir -e apps/hrms/

EXPOSE 8000
CMD ["/home/frappe/entrypoint.sh"]
