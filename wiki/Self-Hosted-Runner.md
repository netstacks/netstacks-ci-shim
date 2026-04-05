# Self-Hosted Runner

GitHub Actions runs in Microsoft's cloud. It cannot reach devices on your network. A self-hosted runner is a process on a machine inside your network that GitHub sends jobs to.

## How It Works

```
GitHub.com                              Your Network
──────────                              ────────────

PR merged → workflow triggers           Self-hosted runner
                                        (Docker container)
       "run this job"                        │
       ─────────────── HTTPS outbound ──►    │
                                             │ gNMI/NETCONF
                                             ▼
                                        Network Devices
                                        10.1.1.100-121
```

**The runner connects outbound to GitHub** over HTTPS (port 443). No inbound firewall rules needed. GitHub never connects to your network — the runner polls GitHub for jobs.

## Setup

### Option A: Docker Container (Recommended)

The repo includes a Dockerfile and helper scripts in `runner/`.

```bash
# Set your GitHub PAT (needs repo + workflow scopes)
export GITHUB_PAT=ghp_your_token_here

# Build and start the runner
cd runner
./start.sh
```

This:
1. Gets a registration token from GitHub
2. Builds the runner Docker image (Ubuntu + Python + dependencies)
3. Starts the container with `--network host` (so it can reach devices)
4. Registers with GitHub as a self-hosted runner

**Verify it's running:**

```bash
docker logs -f netstacks-runner
```

You should see:

```
√ Connected to GitHub
Current runner version: '2.333.1'
Listening for Jobs
```

### Option B: Bare Metal

If you don't want Docker, install the runner directly:

```bash
# On a Linux machine on your network
mkdir actions-runner && cd actions-runner

# Download (check GitHub for latest version)
curl -o runner.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.333.1/actions-runner-linux-x64-2.333.1.tar.gz
tar xzf runner.tar.gz

# Configure
./config.sh --url https://github.com/netstacks/netstacks-ci \
  --token YOUR_REG_TOKEN \
  --name my-runner \
  --labels self-hosted,network

# Install Python dependencies
pip3 install jinja2 pyyaml pygnmi ncclient deepdiff

# Start
./run.sh
```

## Runner Labels

The workflows use `runs-on: [self-hosted, network]`. The runner must have both labels. The `network` label distinguishes it from other self-hosted runners that might not have device access.

When starting the runner, include the labels:

```bash
--labels self-hosted,network
```

## Multiple Runners

For higher parallelism, run multiple runner instances. Each picks up jobs independently.

```bash
# Runner 1
docker run -d --name runner-1 --network host -e RUNNER_NAME=runner-1 ...

# Runner 2
docker run -d --name runner-2 --network host -e RUNNER_NAME=runner-2 ...
```

With two runners and a stack deploying 6 devices, both runners can work on different device jobs simultaneously.

## Security Considerations

- The runner has network access to all devices. Protect the machine it runs on.
- Credentials are in `inventory.yaml` (or vault references). The runner needs access to resolve them.
- The GitHub PAT used for registration should have minimal scopes: `repo` and `workflow`.
- Consider running the container as a non-root user (the Dockerfile already does this).

## Troubleshooting

**Runner not picking up jobs:**
```bash
docker logs netstacks-runner
```
Look for "Listening for Jobs". If not connected, check network/token.

**Jobs fail with "No module named pygnmi":**
The Python dependencies aren't installed in the runner's environment. Rebuild the Docker image or install them manually.

**Jobs fail with connection timeout:**
The runner can't reach the device. Verify the runner machine can reach the device IP and port (6030 for gNMI, 830 for NETCONF).

**Runner appears offline in GitHub:**
The runner process may have died. Restart:
```bash
docker restart netstacks-runner
```
