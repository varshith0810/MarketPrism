# =====================================================================
# Stage 1: Build the React Frontend
# =====================================================================
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend

# Install dependencies with npm ci for reproducible builds
COPY frontend/package*.json ./
RUN npm ci

# Copy frontend source and build static bundle
COPY frontend/ ./
RUN npm run build

# =====================================================================
# Stage 2: Python Backend Runtime
# =====================================================================
FROM python:3.11-slim AS runtime

# AWS Lambda Web Adapter: allows any web framework (FastAPI) to run seamlessly on AWS Lambda
# with native response streaming support for SSE token streaming
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter
RUN chmod +x /opt/extensions/lambda-adapter

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000 \
    AWS_LWA_PORT=8000 \
    AWS_LWA_INVOKE_MODE=response_stream \
    AWS_LWA_READ_TIMEOUT_MS=300000 \
    HOME=/tmp \
    XDG_CACHE_HOME=/tmp

WORKDIR /app

# Install runtime utilities (curl for container healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY MarketInsight/ ./MarketInsight/
COPY config/ ./config/
COPY main.py ./

# Copy built frontend assets from Stage 1 into the container
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Security: run as non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Container health check for AWS App Runner / ECS
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Start Uvicorn ASGI server
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT}"]
