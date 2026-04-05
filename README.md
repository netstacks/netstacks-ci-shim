# NetStacks CI

**Git-native network configuration management.**

Device configs live as structured JSON files in a Git repo. Push to devices via gNMI, NETCONF, or REST APIs. The device handles adds, removes, and modifications — you just declare the desired state.

## Quick Start

```bash
# Setup
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Pull a device's config
./nsci pull pe1-nyc

# Edit it
vim configs/pe1-nyc.json

# Push it back
./nsci push pe1-nyc --full-replace
```

## Commands

```
nsci pull <device>                     Pull device config → configs/<device>.json
nsci push <device> --full-replace      Push config file → device (full replace)
nsci push <d1> <d2> --full-replace     Multi-device push with atomic rollback
nsci diff <device>                     Compare file vs live device
nsci validate <device>                 Check if device matches file
nsci show <device> [section]           Browse config readably
nsci history <device>                  Show change history
nsci rollback <device> N               Restore to previous version (pushes by default)
nsci status                            Show all devices
nsci stack-deploy <stack>              Deploy a named stack
nsci stack-delete <stack>              Remove config deployed by a stack
nsci stack-render <stack> [--delete]   Dry run — preview deploy or delete
nsci stack-list                        List stacks
nsci library [name]                    Browse service templates
nsci serve [--port 8080]               Start API server
```

Use `?` for context-sensitive help: `nsci push ?`, `nsci ?`

## API Server

Run nsci as a REST API for automation and integration:

```bash
# Start the server
nsci serve --port 8080

# With authentication
NSCI_API_TOKEN=mysecret nsci serve --port 8080
```

All CLI commands are available as REST endpoints:

```bash
# Pull a device config
curl -X POST http://localhost:8080/api/v1/devices/pe1-nyc/pull

# Show device status
curl http://localhost:8080/api/v1/status

# Deploy a stack
curl -X POST http://localhost:8080/api/v1/stacks/l3vpn-cust-a/deploy

# With auth
curl -H "Authorization: Bearer mysecret" http://localhost:8080/api/v1/status
```

See [[API Reference]] in the wiki for the full endpoint list.

## How It Works

1. **Pull** a device's config via gNMI → saved as `configs/<device>.json`
2. **Edit** the JSON file (add NTP server, change BGP neighbor, etc.)
3. **Push** the file back via gNMI `Set Replace` → device reconciles
4. **Git tracks** every change — who, what, when, with full rollback

No SSH. No CLI commands. No config parsing. The device's own management plane handles the complexity.

## Installation

```bash
pip install -r requirements.txt
```

| Package | Required | Purpose |
|---|---|---|
| `jinja2` | yes | Template rendering |
| `pyyaml` | yes | YAML parsing (inventory, stacks, schemas) |
| `markupsafe` | yes | XML escaping for templates |
| `pygnmi` | for gNMI | gNMI transport (Arista, Cisco, Nokia, etc.) |
| `ncclient` | for NETCONF | NETCONF transport (Juniper, Cisco, etc.) |
| `deepdiff` | optional | Detailed JSON diffs (`nsci diff`) |
| `argcomplete` | optional | Tab completion |
| `flask` | optional | API server (`nsci serve`) |

### Tab Completion

Enable tab completion for device names, stack names, and commands:

```bash
# One-time setup (add to ~/.bashrc or ~/.zshrc)
eval "$(register-python-argcomplete nsci)"
```

## Documentation

See the **[Wiki](../../wiki)** for complete documentation:

- **[Getting Started](../../wiki/Getting-Started)** — Install, first pull and push
- **[How It Works](../../wiki/How-It-Works)** — Architecture and data flow
- **[Concepts](../../wiki/Concepts)** — Configs, stacks, library, drivers
- **[Command Reference](../../wiki/Command-Reference)** — All commands in detail
- **[API Reference](../../wiki/API-Reference)** — REST API endpoints
- **[Stacks and Atomic Deploys](../../wiki/Stacks-and-Atomic-Deploys)** — Multi-device service deployments
- **[History and Rollback](../../wiki/History-and-Rollback)** — Change tracking and reverting
- **[GitHub Actions Setup](../../wiki/GitHub-Actions-Setup)** — CI/CD automation
- **[Supported Platforms](../../wiki/Supported-Platforms)** — gNMI, NETCONF, REST API devices
- **[FAQ](../../wiki/FAQ)** — Common questions

## Project Structure

```
configs/          One JSON file per device (source of truth)
stacks/           Device groupings for atomic deploys
library/          Reusable service templates (optional)
drivers/          Device communication adapters
nsci              The CLI tool + API server
requirements.txt  Python dependencies
```

## License

Open source. Part of the [NetStacks](https://github.com/netstacks) ecosystem.
