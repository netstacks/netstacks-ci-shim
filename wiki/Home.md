# NetStacks CI

**Git-native network configuration management.**

NetStacks CI (`nsci`) manages network device configurations as structured JSON files in a Git repository. Engineers edit config files, Git tracks every change, and `nsci` pushes configs to devices via gNMI, NETCONF, or REST APIs. The device handles the complexity of applying changes — `nsci` just declares the desired state.

## Why NetStacks CI?

| Traditional Approach | NetStacks CI |
|---|---|
| SSH into device, paste config | Edit a JSON file, push |
| No record of who changed what | Full Git history — who, what, when, why |
| No review before changes hit production | Pull request review with config diffs |
| Rollback means remembering what you had before | `nsci rollback` restores any previous version |
| Scripts break when config syntax changes | Structured APIs — device handles the syntax |
| Each device managed independently | Stacks group devices for atomic deploys |

## Core Principles

1. **Structured APIs only.** No SSH. No CLI scraping. No command generation. Devices are managed through gNMI, NETCONF, or REST APIs.

2. **Git is the source of truth.** Every device's config is a JSON file in the repo. Every change is a commit. Every deploy is traceable.

3. **The device handles the "how."** You declare what the config should look like. The device figures out what to add, remove, or modify. One `replace` operation — not a sequence of CLI commands.

4. **Stacks for atomic operations.** When a service spans multiple devices, a stack groups them. Either all succeed or all roll back.

## Quick Start

```bash
git clone https://github.com/netstacks/netstacks-ci.git
cd netstacks-ci

python3 -m venv .venv && source .venv/bin/activate
pip install jinja2 pyyaml pygnmi ncclient deepdiff

./nsci pull pe1-nyc          # Pull device config
vim configs/pe1-nyc.json     # Edit it
./nsci push pe1-nyc          # Push it back
```

See [[Getting Started]] for a complete walkthrough.

---

## Wiki Contents

### Fundamentals
- [[Getting Started]] — Install, configure, first pull and push
- [[How It Works]] — Architecture, data flow, what happens when you push
- [[Concepts]] — Configs, stacks, library, drivers explained

### Daily Usage
- [[Managing Device Configs]] — Pull, edit, push, validate
- [[Browsing Configs]] — The `show` command for readable config views
- [[Stacks and Atomic Deploys]] — Grouping devices for service deployments
- [[History and Rollback]] — Viewing changes and reverting to previous versions
- [[Config Diffs]] — Comparing your file against the live device

### CI/CD Integration
- [[GitHub Actions Setup]] — Workflows for automated preview and deploy
- [[Self-Hosted Runner]] — Running the deploy agent on your network
- [[Branch Protection]] — Protecting main with reviews and approvals
- [[CODEOWNERS]] — Per-device approval requirements

### Templates and Library
- [[Service Templates]] — Reusable Jinja2 templates for common services
- [[Writing Templates]] — How to create new templates for the library
- [[Template Schemas]] — Variable definitions for UI integration

### Drivers and Transports
- [[Supported Platforms]] — gNMI, NETCONF, REST API device support
- [[gNMI Transport]] — How Arista EOS and other gNMI devices work
- [[NETCONF Transport]] — How IOS-XR, Junos, and NETCONF devices work
- [[REST API Transport]] — How Palo Alto, F5, and API-driven devices work
- [[Writing Drivers]] — Adding support for new device types

### Reference
- [[Command Reference]] — Complete list of all `nsci` commands
- [[Repository Structure]] — Directory layout and file purposes
- [[FAQ]] — Common questions and troubleshooting
