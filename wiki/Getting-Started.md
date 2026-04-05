# Getting Started

This guide walks you through setting up NetStacks CI from scratch — installing dependencies, adding your first device, pulling its config, making a change, and pushing it.

## Prerequisites

- **Python 3.10+** — `nsci` is a Python tool
- **Git** — configs are stored in a Git repo
- **Network devices** with structured API access:
  - Arista EOS with eAPI or gNMI enabled
  - Cisco IOS-XR with NETCONF enabled
  - Juniper Junos with NETCONF enabled
  - Palo Alto with REST API access
  - Any device with a gNMI, NETCONF, or REST API

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/netstacks/netstacks-ci.git
cd netstacks-ci
```

### 2. Create a Python Virtual Environment

```bash
python3 -m venv .venv
source .venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install jinja2 pyyaml pygnmi ncclient deepdiff
```

| Package | Purpose |
|---|---|
| `jinja2` | Template rendering for the service library |
| `pyyaml` | Reading YAML config files (inventory, stacks, schemas) |
| `pygnmi` | gNMI transport for Arista EOS and other gNMI devices |
| `ncclient` | NETCONF transport for IOS-XR, Junos, and other NETCONF devices |
| `deepdiff` | Detailed JSON comparison for the `diff` command |

### 4. Verify Installation

```bash
./nsci status
```

You should see the device inventory table. If the command fails, make sure your virtual environment is activated.

## Adding Your First Device

### 1. Enable gNMI on Your Arista Device

On the Arista EOS device:

```
configure
management api gnmi
   transport grpc default
   no shutdown
exit
management api netconf
   transport ssh default
   no shutdown
exit
end
write memory
```

This enables gNMI on port 6030 and NETCONF on port 830.

### 2. Add the Device to Inventory

Edit `inventory.yaml`:

```yaml
devices:
  my-switch:
    hostname: 10.0.0.1
    driver: eos-gnmi
    credential:
      username: admin
      password: admin123
```

**In production**, use vault references instead of plaintext credentials:

```yaml
    credential: vault://network/my-switch
```

### 3. Verify Connectivity

```bash
./nsci status
```

You should see your device listed:

```
Device               Hostname           Driver             Config File
---------------------------------------------------------------------------
my-switch            10.0.0.1           eos-gnmi           not pulled
```

## First Pull

Pull the device's running config into the repo:

```bash
./nsci pull my-switch
```

Output:

```
Pulling config from my-switch (10.0.0.1)...
Saved: configs/my-switch.json
Sections: acl, interfaces, network-instances, routing-policy, system
```

This creates `configs/my-switch.json` — the full device configuration as structured JSON. This file is now the source of truth for that device.

## Browse the Config

```bash
# Overview of all sections
./nsci show my-switch

# Drill into a section
./nsci show my-switch system/ntp

# See interfaces
./nsci show my-switch interfaces
```

The `show` command presents the JSON in a readable format. You never need to open the raw JSON file to understand what's on the device.

## Make a Change

Now let's add an NTP server. You can either:

**Option A: Edit the JSON directly**

Open `configs/my-switch.json`, find the NTP section, add a server entry. This works but the file is large.

**Option B: Use the `show` command to find what you need, then edit**

```bash
./nsci show my-switch system/ntp
```

Shows you the current NTP config. Find the same section in the JSON file and edit it.

### Example: Adding an NTP Server

In `configs/my-switch.json`, find the `openconfig-system:system` → `ntp` → `servers` → `server` array and add:

```json
{
  "address": "10.0.0.99",
  "config": {
    "address": "10.0.0.99"
  }
}
```

## Preview the Change

Before pushing, see what would change on the device:

```bash
./nsci diff my-switch
```

This pulls the live config from the device and compares it to your file. It shows exactly what's different.

## Push the Change

```bash
./nsci push my-switch
```

Output:

```
Pushing config to my-switch (10.0.0.1)...
gNMI Set: REPLACE
Device config replaced from configs/my-switch.json
```

The device now matches your file. The gNMI `replace` operation handled adding the NTP server — you didn't generate any CLI commands.

## Validate

Confirm the device matches:

```bash
./nsci validate my-switch
```

```
Validating my-switch (10.0.0.1)...
IN SYNC: my-switch matches config file
```

## Commit to Git

```bash
git add configs/my-switch.json
git commit -m "Add NTP server 10.0.0.99 to my-switch"
git push
```

The change is now tracked in Git with full history. Anyone can see who made the change, when, and why.

## What's Next

- [[Managing Device Configs]] — Pull, edit, push, validate in detail
- [[Stacks and Atomic Deploys]] — Group devices for service deployments
- [[GitHub Actions Setup]] — Automate preview and deploy on PR merge
- [[History and Rollback]] — View change history and revert changes
