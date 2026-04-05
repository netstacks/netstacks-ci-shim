# Managing Device Configs

The core workflow: pull, edit, push, validate.

## The Config File

Each device has one JSON file: `configs/<device-name>.json`. This contains the full running config as structured JSON in OpenConfig format.

Example sections in a typical Arista EOS config file:

| Section | What It Contains |
|---|---|
| `openconfig-system:system` | Hostname, NTP, DNS, AAA, SNMP, logging |
| `openconfig-interfaces:interfaces` | Physical interfaces, loopbacks, SVIs |
| `openconfig-network-instance:network-instances` | VRFs, BGP, OSPF, ISIS, static routes |
| `openconfig-routing-policy:routing-policy` | Route-maps, community lists, prefix lists |
| `openconfig-acl:acl` | Access control lists |
| `openconfig-lldp:lldp` | LLDP settings |
| `openconfig-qos:qos` | QoS policies |

## Onboarding a New Device

### 1. Add to Inventory

```yaml
# inventory.yaml
devices:
  pe5-lax:
    hostname: 10.1.1.108
    driver: eos-gnmi
    credential:
      username: admin
      password: admin123
```

### 2. Pull the Config

```bash
nsci pull pe5-lax
```

This creates `configs/pe5-lax.json`. The device is now managed.

### 3. Commit the Baseline

```bash
git add inventory.yaml configs/pe5-lax.json
git commit -m "Onboard pe5-lax"
git push
```

## Making Changes

### The Workflow

```
1. Edit configs/<device>.json       ← make your change
2. nsci show <device> <section>     ← verify it looks right (optional)
3. nsci diff <device>               ← preview against live device (optional)
4. nsci push <device>               ← apply to device
5. nsci validate <device>           ← confirm device matches (optional)
6. git commit && git push           ← record the change
```

Steps 2, 3, and 5 are optional but recommended. In a CI workflow, only step 1 and the git push are manual — everything else is automated.

### Adding Config

Adding an NTP server. Find the NTP section in the JSON file:

```json
"ntp": {
  "servers": {
    "server": [
      {
        "address": "10.0.0.1",
        "config": { "address": "10.0.0.1" }
      }
    ]
  }
}
```

Add a new entry to the array:

```json
"ntp": {
  "servers": {
    "server": [
      {
        "address": "10.0.0.1",
        "config": { "address": "10.0.0.1" }
      },
      {
        "address": "10.0.0.2",
        "config": { "address": "10.0.0.2", "prefer": true }
      }
    ]
  }
}
```

Push. The device adds the second NTP server.

### Removing Config

Remove the NTP server entry from the array:

```json
"ntp": {
  "servers": {
    "server": [
      {
        "address": "10.0.0.1",
        "config": { "address": "10.0.0.1" }
      }
    ]
  }
}
```

Push. The device removes the second NTP server. You didn't generate `no ntp server 10.0.0.2` — the gNMI `replace` operation saw the server was missing from the payload and removed it.

### Modifying Config

Change the BGP neighbor description:

```json
"description": "RR1-NYC Primary"
```

Push. The device updates the description. Same `replace` operation — you sent the new value, the device applied it.

## Handling Drift

Drift occurs when someone changes the device outside of `nsci` (manual CLI change, another automation tool, etc.).

### Detecting Drift

```bash
nsci validate pe1-nyc
```

```
DRIFT: pe1-nyc does not match config file
  Run 'nsci diff pe1-nyc' for details
  Run 'nsci push pe1-nyc' to fix
```

### Investigating Drift

```bash
nsci diff pe1-nyc
```

Shows exactly what differs between your file and the live device.

### Resolving Drift

**Option A: Push your file (reject the manual change)**

```bash
nsci push pe1-nyc
```

The device reverts to what your file says.

**Option B: Pull the device (accept the manual change)**

```bash
nsci pull pe1-nyc
git add configs/pe1-nyc.json
git commit -m "Accept manual change on pe1-nyc: added SNMP community"
git push
```

The file updates to match the device. The manual change is now tracked in Git.

## Multiple Devices

### Bulk Pull

Pull all devices at once (useful for initial onboarding):

```bash
for device in $(nsci status | awk 'NR>2 {print $1}'); do
  nsci pull "$device"
done
```

### Bulk Validate

Check all devices for drift:

```bash
for device in $(nsci status | awk 'NR>2 {print $1}'); do
  nsci validate "$device"
done
```

### Atomic Multi-Device Push

See [[Stacks and Atomic Deploys]] for deploying to multiple devices as one unit.
