#!/bin/bash
# Start a self-hosted GitHub Actions runner as a Docker container.
# This runs on your network so it can reach your devices.

set -e

REPO="netstacks/netstacks-ci-shim"
TOKEN_URL="https://api.github.com/repos/${REPO}/actions/runners/registration-token"
PAT="${GITHUB_PAT:?Set GITHUB_PAT environment variable}"

# Get a fresh registration token
echo "Getting registration token..."
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ${PAT}" \
  -H "Accept: application/vnd.github+json" \
  "${TOKEN_URL}" | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

echo "Registration token: ${REG_TOKEN:0:5}..."

# Build the runner image if needed
echo "Building runner image..."
docker build -t netstacks-runner runner/

# Remove old container if exists
docker rm -f netstacks-runner 2>/dev/null || true

# Run the container
# --network host so it can reach devices on the local network
echo "Starting runner..."
docker run -d \
  --name netstacks-runner \
  --network host \
  --restart unless-stopped \
  netstacks-runner \
  bash -c "./config.sh --url https://github.com/${REPO} --token ${REG_TOKEN} --name netstacks-runner --unattended --replace && ./run.sh"

echo ""
echo "Runner started. Check status:"
echo "  docker logs -f netstacks-runner"
