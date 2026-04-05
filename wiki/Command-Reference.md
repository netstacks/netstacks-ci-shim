# Command Reference

Complete reference for all `nsci` commands.

## Device Operations

### `nsci pull <device>`

Pull a device's running config and save it as `configs/<device>.json`.

```bash
nsci pull pe1-nyc
```

**What it does:**
1. Connects to the device via gNMI (or NETCONF, depending on driver)
2. Sends a `Get` request for the full config
3. Saves the response as `configs/<device>.json`

**When to use:**
- First time onboarding a device
- After making manual changes on the device (to re-sync the file)
- To get a fresh baseline before making changes

**Output:**
```
Pulling config from pe1-nyc (10.1.1.104)...
Saved: configs/pe1-nyc.json
Sections: acl, interfaces, network-instances, routing-policy, system
```

---

### `nsci push <device> [device2 ...] --full-replace [--workers N] [--no-atomic]`

Push `configs/<device>.json` to one or more devices. Requires `--full-replace` — this is a full config replace, and nsci makes you say so.

```bash
# Single device
nsci push pe1-nyc --full-replace

# Multiple devices (parallel, atomic by default)
nsci push pe1-nyc pe2-nyc pe3-chi --full-replace

# Multiple devices, non-atomic
nsci push pe1-nyc pe2-nyc pe3-chi --full-replace --no-atomic

# Control parallelism
nsci push pe1-nyc pe2-nyc pe3-chi --full-replace --workers 20
```

**Without `--full-replace`:**
```
ERROR: full config replace requires --full-replace
  This replaces the ENTIRE running config on the device.
  If that's what you want: nsci push pe1-nyc --full-replace
```

**What it does:**
1. Reads `configs/<device>.json`
2. Connects to the device
3. Sends a gNMI `Set` with `replace` on the root path
4. The device reconciles its running config to match the file
5. Pulls config back from the device and updates `configs/` (so the file matches actual device state)

For multiple devices, adds pre-flight snapshots and atomic rollback (same stages as stack-deploy).

**When to use:**
- After editing a device's config file
- To correct drift (device was changed outside of `nsci`)
- To restore a rolled-back config

**Options (multi-device only):**

| Flag | Default | Description |
|---|---|---|
| `--workers` | 10 | Number of parallel threads |
| `--no-atomic` | false | Allow partial success (skip rollback) |

**Output (single device):**
```
Pushing config to pe1-nyc (10.1.1.104)...
  pe1-nyc: gNMI Set REPLACE
  pe1-nyc: synced
```

**Output (multi-device):**
```
Full config replace to 3 devices (workers=3, atomic=True)
  Devices: pe1-nyc, pe2-nyc, pe3-chi

Pre-flight (saving rollback snapshots)...
  pe1-nyc: OK (snapshot saved)
  pe2-nyc: OK (snapshot saved)
  pe3-chi: OK (snapshot saved)

Pushing configs...
  pe1-nyc: PUSHED
  pe2-nyc: PUSHED
  pe3-chi: PUSHED

Validating...
  pe1-nyc: IN SYNC
  pe2-nyc: IN SYNC
  pe3-chi: IN SYNC

Syncing configs/...
  pe1-nyc: synced
  pe2-nyc: synced
  pe3-chi: synced

PUSH SUCCEEDED — 3 devices updated.
```

**Exit code:** 0 on success, 1 on failure.

---

### `nsci diff <device>`

Compare the local config file against the live device.

```bash
nsci diff pe1-nyc
```

**What it does:**
1. Reads `configs/<device>.json` (local)
2. Pulls current config from the device (live)
3. Performs a deep JSON comparison
4. Reports differences

**Output (no differences):**
```
pe1-nyc: no differences (file matches device)
```

**Output (differences found):**
```
pe1-nyc: differences found

  values_changed:
    root['openconfig-system:system']['ntp']['servers']['server'][2]: ...

  dictionary_item_added:
    root['openconfig-system:system']['ntp']['servers']['server'][3]: ...
```

---

### `nsci validate <device>`

Quick check: does the device match the config file? (Yes/no, no details.)

```bash
nsci validate pe1-nyc
```

**Output:**
```
IN SYNC: pe1-nyc matches config file
```
or
```
DRIFT: pe1-nyc does not match config file
  Run 'nsci diff pe1-nyc' for details
  Run 'nsci push pe1-nyc' to fix
```

**Exit code:** 0 if in sync, 1 if drift detected.

---

### `nsci show <device> [section]`

Browse device config in a readable format.

```bash
# Top-level overview
nsci show pe1-nyc

# Drill into a section
nsci show pe1-nyc system/ntp

# See interfaces
nsci show pe1-nyc interfaces

# See a specific interface
nsci show pe1-nyc interfaces/Ethernet1
```

**What it does:** Reads the local config file (not the device) and presents it as a readable tree. Strips OpenConfig namespace prefixes for clarity.

**Output (top-level):**
```
pe1-nyc config sections:

  acl/
    acl-sets
  interfaces/
    interface
  network-instances/
    network-instance
  system/
    aaa
    config
    ntp
    ...
```

**Output (section):**
```
nsci show pe1-nyc system/ntp

servers:
  server:
    address: 10.0.0.1
    config:
      address: 10.0.0.1
    ---
    address: 10.0.0.2
    config:
      address: 10.0.0.2
      prefer: True
    ---
```

---

## Stack Operations

### `nsci stack-render <stack-name> [--delete]`

Dry run — render all templates in a stack without pushing anything.

```bash
# Show what would be deployed
nsci stack-render l3vpn-cust-a

# Show what would be deleted
nsci stack-render l3vpn-cust-a --delete
```

**What it does:** Resolves all services × devices, renders Jinja2 templates, and displays the output. With `--delete`, shows per-item delete paths (gNMI) and XML with `nc:operation="delete"` (NETCONF).

**Output:**
```
Stack: l3vpn-cust-a
...
[bgp-neighbor] → pe1-nyc (driver=eos-gnmi, template=bgp-neighbor/template.json.j2)
  target: /openconfig-network-instance:.../bgp (merge)
  { "global": { "config": { "as": 65000 ... } } }
```

**With `--delete`:**
```
Stack: l3vpn-cust-a (DELETE)
...
[bgp-neighbor] → pe1-nyc (driver=eos-gnmi, template=bgp-neighbor/template.json.j2)
  gNMI SET DELETE /.../bgp/neighbors/neighbor[neighbor-address=10.255.0.2]
```

---

### `nsci stack-deploy <stack-name>`

Deploy a named stack: render → pre-flight → push → validate → confirm → sync.

```bash
nsci stack-deploy l3vpn-cust-a
```

**What it does:**

| Stage | What Happens |
|---|---|
| Render | Resolve all services × devices, render Jinja2 templates |
| Pre-flight | Pull current config from each device (rollback snapshots) |
| Push | Send rendered templates (serialized per device, parallel across devices) |
| Validate | Deep-compare rendered config against live device state |
| Confirm | Send confirming commit to NETCONF commit-confirm devices |
| Sync | Pull full config back from each device, save to `configs/` |

---

### `nsci stack-delete <stack-name>`

Remove all config deployed by a stack. Uses the same `stack.yaml` — no extra files needed.

```bash
nsci stack-delete l3vpn-cust-a
```

**What it does:**

| Stage | What Happens |
|---|---|
| Resolve | Render templates to determine what was deployed |
| Delete | Remove per-item: gNMI `Set delete`, NETCONF `nc:operation="delete"` |
| Confirm | Send confirming commit to NETCONF commit-confirm devices |
| Sync | Pull full config back, save to `configs/` |

**How delete works by transport:**

- **gNMI (OpenConfig):** Walks rendered JSON, builds per-list-item delete paths. `DELETE .../neighbor[neighbor-address=X]` — only that neighbor is removed.
- **NETCONF (OpenConfig):** Injects `nc:operation="delete"` on list item elements (`<static>`, `<neighbor>`, `<server>`, etc.).
- **NETCONF (vendor-native):** Swaps all `nc:operation="replace"` and `nc:operation="merge"` to `nc:operation="delete"`. Template creators must use explicit `nc:operation` on every operational element.

**Output:**
```
Stack: l3vpn-cust-a (DELETE)
...
  [bgp-neighbor] → pe1-nyc: DELETE .../neighbor[neighbor-address=10.255.0.2]
  [bgp-import-policy] → pe1-nyc: DELETE .../community-set[name=CUST-A-COMMS]
  [bgp-import-policy] → pe1-nyc: DELETE .../policy-definition[name=CUST-A-IMPORT]
  [ntp] → pe1-nyc: DELETE .../server[address=10.0.0.1]
  ...
  6 deletions planned

DELETE COMPLETE — l3vpn-cust-a
  6 services removed from 2 devices
```

---

### `nsci stack-list`

List all defined stacks.

```bash
nsci stack-list
```

**Output:**
```
Stack                     Atomic     Devices  Description
--------------------------------------------------------------------------------
baseline-ntp              no         9        NTP server standardization
l3vpn-cust-a              yes        3        L3VPN service for Customer A
```

---

## History and Rollback

### `nsci history <device> [--count N] [--diff N]`

Show change history for a device's config file.

```bash
# Last 10 changes
nsci history pe1-nyc

# Last 20 changes
nsci history pe1-nyc --count 20

# Show diff for a specific version
nsci history pe1-nyc --diff 0
```

**Output:**
```
History for pe1-nyc:

  0: 67ceb93  2 min ago   Add NTP server 10.0.0.99          (current)
  1: 60c1dc1  1 hour ago  Update BGP neighbor config
  2: c6b2820  3 days ago  Initial pull from NetBox

To rollback: nsci rollback pe1-nyc <number>
To see diff: nsci history pe1-nyc --diff <number>
```

**With `--diff`:** Shows the git diff for that version with color-coded additions (green) and removals (red).

---

### `nsci rollback <device> <version> [--no-push]`

Rollback a device to a previous config version. Pushes to the device by default.

```bash
# Rollback file AND push to device (default)
nsci rollback pe1-nyc 1

# Rollback file only — don't touch the device
nsci rollback pe1-nyc 1 --no-push
```

**What it does:**
1. Reads the git history for `configs/<device>.json`
2. Restores the file to the specified version
3. Creates a git commit recording the rollback
4. Pushes the rolled-back config to the device
5. Syncs `configs/` back from the device (so the file matches actual device state)

**Output:**
```
Rolling back pe1-nyc to version 1:
  60c1dc1  1 hour ago  Update BGP neighbor config

  Changes: +12 lines, -47 lines
  Restored configs/pe1-nyc.json to version 1
  Committed: Rollback pe1-nyc to version 1 (60c1dc1)

Pushing rollback to pe1-nyc...
  PUSHED — pe1-nyc restored to version 1
  Synced configs/pe1-nyc.json with live device
```

**With `--no-push`:** The file is restored and committed, but the device is not touched. Use this when you want to review the rollback first, then either:
- `nsci push pe1-nyc` to apply it manually
- Open a PR, merge → CI deploys

---

## Informational

### `nsci status`

Show all devices and their config file state.

```bash
nsci status
```

**Output:**
```
Device               Hostname           Driver             Config File
---------------------------------------------------------------------------
rr1-nyc              10.1.1.100         eos-gnmi           130KB
pe1-nyc              10.1.1.104         eos-gnmi           126KB
ce1-nyc-globalbank   10.1.1.110         cisco-ios          not pulled
sw3-lax-mediastream  10.1.1.121         eos-gnmi           not pulled
```

---

### `nsci library [service]`

Browse available service templates.

```bash
# List all templates
nsci library

# Details for a specific template
nsci library ntp
```

**Output (list):**
```
Service                   Platforms                 Description
--------------------------------------------------------------------------------
bgp-neighbor              eos                       BGP peering configuration
fw-security-rule          paloalto                  Palo Alto firewall security policy rule
ntp                       eos, ios, iosxr           NTP server configuration
snmp                      eos, ios                  SNMP monitoring configuration
```

**Output (detail):**
```
Service: ntp
Description: NTP server configuration
Platforms: eos, ios, iosxr

  ntp_servers (list, required): NTP servers to configure
```
