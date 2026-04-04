#!/bin/bash
set -e

# Configure the runner if not already configured
if [ ! -f .runner ]; then
    echo "Configuring runner..."
    ./config.sh \
        --url "https://github.com/${REPO}" \
        --token "${REG_TOKEN}" \
        --name "${RUNNER_NAME:-netstacks-runner}" \
        --labels "${RUNNER_LABELS:-self-hosted,network}" \
        --unattended \
        --replace
fi

echo "Starting runner..."
exec ./run.sh
