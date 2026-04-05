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

### `nsci push <device>`

Push `configs/<device>.json` to the device.

```bash
nsci push pe1-nyc
```

**What it does:**
1. Reads `configs/<device>.json`
2. Connects to the device
3. Sends a gNMI `Set` with `replace` on the root path
4. The device reconciles its running config to match the file

**When to use:**
- After editing a device's config file
- To correct drift (device was changed outside of `nsci`)
- To restore a rolled-back config

**Output:**
```
Pushing config to pe1-nyc (10.1.1.104)...
gNMI Set: REPLACE
Device config replaced from configs/pe1-nyc.json
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

## Multi-Device Operations

### `nsci deploy <device1> <device2> ... [--workers N] [--no-atomic]`

Deploy config to multiple devices in parallel with optional atomic rollback.

```bash
# Atomic (default): all succeed or all roll back
nsci deploy pe1-nyc pe2-nyc pe3-chi

# Non-atomic: each device independent
nsci deploy pe1-nyc pe2-nyc pe3-chi --no-atomic

# Control parallelism
nsci deploy pe1-nyc pe2-nyc pe3-chi --workers 20
```

**Stages:**

| Stage | What Happens |
|---|---|
| Pre-flight | Pull current config from all devices (rollback snapshots) |
| Push | Send new configs to all devices in parallel |
| Validate | Verify all devices match expected state |
| Rollback | If any failed AND `atomic=true`: restore ALL to pre-flight state |

**Options:**

| Flag | Default | Description |
|---|---|---|
| `--workers` | 10 | Number of parallel threads |
| `--no-atomic` | false | Allow partial success (skip rollback) |

**Output:**
```
Deploy to 3 devices (workers=3, atomic=True)
  Devices: pe1-nyc, pe2-nyc, pe3-chi

Stage 1: Pre-flight (saving rollback snapshots)...
  pe1-nyc: OK (snapshot saved)
  pe2-nyc: OK (snapshot saved)
  pe3-chi: OK (snapshot saved)

Stage 2: Pushing configs...
  pe1-nyc: PUSHED
  pe2-nyc: PUSHED
  pe3-chi: PUSHED

Stage 3: Validating...
  pe1-nyc: IN SYNC
  pe2-nyc: IN SYNC
  pe3-chi: IN SYNC

DEPLOY SUCCEEDED — 3 devices updated.
```

---

### `nsci stack-deploy <stack-name>`

Deploy a named stack from `stacks/<name>/stack.yaml`.

```bash
nsci stack-deploy l3vpn-cust-a
```

**What it does:** Reads the stack definition and calls `deploy` with the stack's device list, atomic setting, and worker count.

**Equivalent to:**
```bash
# stacks/l3vpn-cust-a/stack.yaml has: atomic=true, devices=[pe1-nyc, pe2-nyc, ce1-nyc]
nsci deploy pe1-nyc pe2-nyc ce1-nyc-globalbank --workers 3
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

### `nsci rollback <device> <version> [--push]`

Rollback a device's config file to a previous version.

```bash
# Rollback file only (doesn't push to device)
nsci rollback pe1-nyc 1

# Rollback file AND push to device immediately
nsci rollback pe1-nyc 1 --push
```

**What it does:**
1. Reads the git history for `configs/<device>.json`
2. Restores the file to the specified version
3. Creates a git commit recording the rollback
4. Optionally pushes the rolled-back config to the device

**Output:**
```
Rolling back pe1-nyc to version 1:
  60c1dc1  1 hour ago  Update BGP neighbor config

  Changes: +12 lines, -47 lines
  Restored configs/pe1-nyc.json to version 1
  Committed: Rollback pe1-nyc to version 1 (60c1dc1)

Pushing rollback to pe1-nyc...
  PUSHED — pe1-nyc restored to version 1
```

**Without `--push`:** The file is restored and committed, but not pushed to the device. You can review the rollback, then either:
- `nsci push pe1-nyc` to apply it manually
- `git push` to trigger CI auto-deploy

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
