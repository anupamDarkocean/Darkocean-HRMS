FROM python:3.10-slim

WORKDIR /app

# Install system dependencies required for Frappe
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    wget \
    nodejs \
    npm \
    libssl-dev \
    libjpeg-dev \
    zlib1g-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Node globally
RUN npm install -g yarn n && n 18

# Copy project files
COPY . .

# Install Python dependencies with flit
RUN pip install --no-cache-dir "flit_core>=3.4,<4"

# Install hrms package
RUN pip install --no-cache-dir -e .

# Install frontend dependencies
RUN yarn install --frozen-lockfile

# Build frontend applications
RUN yarn build

# Create bench directory structure
RUN mkdir -p /workspace/apps /workspace/sites

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/api/health || exit 1

# Start server
CMD ["bench", "serve", "--port", "8000", "--host", "0.0.0.0"]
