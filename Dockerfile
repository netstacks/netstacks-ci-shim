FROM python:3.12-slim

# Install git for local repo operations (history, rollback, auto-commit)
RUN apt-get update && apt-get install -y --no-install-recommends git curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy nsci and supporting files
COPY nsci .
COPY library/ library/
COPY drivers/ drivers/
COPY stacks/ stacks/

# Create directories for runtime data
RUN mkdir -p configs snapshots

# Initialize local git repo for config tracking
RUN git config --global user.email "nsci@netstacks.io" && \
    git config --global user.name "nsci" && \
    git init && git add -A && git commit -m "initial"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -sf http://localhost:8080/api/v1/health || exit 1

# Default: serve on port 8080
CMD ["python", "nsci", "serve", "--port", "8080"]
