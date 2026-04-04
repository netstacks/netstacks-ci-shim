# netstacks-ci-shim

Git-native network configuration management. Define what you want on your devices in simple YAML files, and the shim renders, deploys, and validates via structured APIs (eAPI, NETCONF, gNMI). No SSH. No CLI scraping.

## How it works

```
You edit this:              The shim produces:           The device gets:

stacks/                     rendered/                    Config via eAPI/
  my-service/                 device-name/               NETCONF/gNMI
    variables.yaml              my-service.cfg
```

## Quick start

```bash
# 1. Create a Python venv
python3 -m venv .venv && source .venv/bin/activate
pip install jinja2 pyyaml

# 2. Add a device to inventory
#    Edit inventory.yaml with your device details

# 3. Pick a template, create a stack, fill in variables
#    See stacks/base-ntp/ for an example

# 4. Render, preview, deploy
./shim render                    # Generate device configs
./shim diff <device>             # Preview changes on live device
./shim deploy <device>           # Push config to device
./shim validate <device>         # Verify device matches
```

## Project structure

```
netstacks-ci-shim/
│
├── inventory.yaml            # Your devices: hostname, driver, credentials
│
├── library/                  # Service templates (Jinja2) + variable schemas
│   ├── ntp/
│   │   ├── README.md         # What this service does, what variables it needs
│   │   ├── template.j2       # The Jinja2 template (per-platform sections inside)
│   │   └── schema.yaml       # Variable definitions: name, type, required, description
│   ├── snmp/
│   ├── bgp-neighbor/
│   └── ...
│
├── stacks/                   # Your deployments: which template → which devices
│   ├── site-nyc-ntp/
│   │   ├── stack.yaml        # Template reference + device list
│   │   └── variables.yaml    # Your values
│   └── ...
│
├── drivers/                  # Device communication adapters
│   ├── eos-eapi/
│   ├── iosxr-netconf/
│   └── ...
│
├── rendered/                 # Auto-generated: what each device will receive
│   └── leaf01-eos/
│       ├── base-ntp.cfg
│       └── base-snmp.cfg
│
├── shim                      # The CLI tool
└── .github/workflows/        # Optional: CI/CD automation
```

## Concepts

**Library** — Reusable service templates. Like NSO service packages but simpler.
Someone builds these once. Engineers pick from the library.

**Stack** — A deployment of a template to specific devices with specific values.
This is what engineers create. Just YAML: which template, which devices, what values.

**Driver** — How to talk to a device type. Ships with the shim or community-contributed.
Engineers never touch these.

**Rendered** — Auto-generated config fragments. What will actually go to each device.
Created by `shim render`. Committed to Git so changes are visible in PRs.
```
