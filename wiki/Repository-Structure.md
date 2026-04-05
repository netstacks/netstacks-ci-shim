# Repository Structure

```
netstacks-ci/
│
├── nsci                              The CLI tool
├── inventory.yaml                    Device inventory
├── CODEOWNERS                        Per-device approval rules
│
├── configs/                          Device configurations
│   ├── rr1-nyc.json                  Full config for each device
│   ├── p1-nyc.json                   as structured JSON (OpenConfig)
│   ├── pe1-nyc.json
│   └── ...
│
├── stacks/                           Device groupings
│   ├── l3vpn-cust-a/
│   │   └── stack.yaml                atomic: true, devices: [pe1, pe2, ce1]
│   └── baseline-ntp/
│       └── stack.yaml                atomic: false, devices: [all EOS]
│
├── library/                          Service templates (optional)
│   ├── ntp/
│   │   ├── README.md                 What this service does
│   │   ├── schema.yaml               Variable definitions
│   │   └── template.xml.j2           Jinja2 → NETCONF XML
│   ├── bgp-neighbor/
│   │   ├���─ README.md
│   │   └── schema.yaml
│   ├── fw-security-rule/
│   │   ├── README.md
│   │   ├── schema.yaml
│   │   └── template.json.j2          Jinja2 → REST API JSON
│   └── snmp/
│       ├── README.md
│       └── schema.yaml
│
├── drivers/                          Device communication adapters
│   ├── eos-gnmi/
│   │   └── driver.yaml               gNMI on port 6030
│   ├── eos-eapi/
│   │   └── driver.yaml               eAPI on port 443
│   ├── iosxr-netconf/
│   │   └── driver.yaml               NETCONF on port 830
│   └── paloalto-panorama/
│       └── driver.yaml               REST API with endpoint definitions
│
├── runner/                           Self-hosted GitHub Actions runner
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── start.sh
│
├── .github/workflows/                CI/CD automation
│   ├── preview.yaml                  Runs on PR: shows config diffs
│   └── deploy.yaml                   Runs on merge: deploys to devices
│
├── .gitignore
└── README.md
```

## What Each Directory Is For

| Directory | Who Uses It | Purpose |
|---|---|---|
| `configs/` | Engineers (daily) | The source of truth. One JSON file per device. Edit these to make changes. |
| `stacks/` | Engineers (when creating services) | Groups devices for atomic deploys. Defines which devices go together. |
| `library/` | Platform team (builds), Engineers (browses) | Reusable templates for standard services. Optional. |
| `drivers/` | Nobody day-to-day | How to talk to each device type. Ships with `nsci`. |
| `runner/` | Ops team (one-time setup) | Docker files for the self-hosted CI runner. |
| `.github/workflows/` | Nobody day-to-day | CI automation. Runs automatically. |

## What Engineers Touch

**Day-to-day:** Only `configs/<device>.json` files. Pull, edit, push.

**When creating a service:** Also `stacks/<service>/stack.yaml` to group devices.

**Never:** `drivers/`, `library/` (unless they're building new templates), `runner/`, `.github/workflows/`.
