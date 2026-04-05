# NetStacks CI

**Git-native network configuration management.**

Device configs live as structured JSON files in a Git repo. Push to devices via gNMI, NETCONF, or REST APIs. The device handles adds, removes, and modifications — you just declare the desired state.

## Quick Start

```bash
# Setup
python3 -m venv .venv && source .venv/bin/activate
pip install jinja2 pyyaml pygnmi ncclient deepdiff

# Pull a device's config
./nsci pull pe1-nyc

# Edit it
vim configs/pe1-nyc.json

# Push it back
./nsci push pe1-nyc
```

## Commands

```
nsci pull <device>                Pull device config → configs/<device>.json
nsci push <device>                Push config file → device
nsci deploy <devices...>          Parallel push with atomic rollback
nsci stack-deploy <stack>         Deploy a named stack
nsci diff <device>                Compare file vs live device
nsci validate <device>            Check if device matches file
nsci show <device> [section]      Browse config readably
nsci history <device>             Show change history
nsci rollback <device> N [--push] Restore to previous version
nsci status                       Show all devices
nsci stack-list                   List stacks
nsci library [name]               Browse service templates
```

## How It Works

1. **Pull** a device's config via gNMI → saved as `configs/<device>.json`
2. **Edit** the JSON file (add NTP server, change BGP neighbor, etc.)
3. **Push** the file back via gNMI `Set Replace` → device reconciles
4. **Git tracks** every change — who, what, when, with full rollback

No SSH. No CLI commands. No config parsing. The device's own management plane handles the complexity.

## Documentation

See the **[Wiki](../../wiki)** for complete documentation:

- **[Getting Started](../../wiki/Getting-Started)** — Install, first pull and push
- **[How It Works](../../wiki/How-It-Works)** — Architecture and data flow
- **[Concepts](../../wiki/Concepts)** — Configs, stacks, library, drivers
- **[Command Reference](../../wiki/Command-Reference)** — All commands in detail
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
nsci              The CLI tool
```

## License

Open source. Part of the [NetStacks](https://github.com/netstacks) ecosystem.
