# How It Works

## The Big Picture

```
┌─────────────────────────────────────────────────────────┐
│                     Git Repository                       │
│                                                          │
│  configs/                                                │
│    pe1-nyc.json  ← full device config as structured JSON │
│    pe2-nyc.json                                          │
│    rr1-nyc.json                                          │
│                                                          │
└────────────┬──────────────────────────────┬──────────────┘
             │                              │
        Engineer edits               Merge to main
        a config file                      │
             │                              ▼
             │                   ┌─────────────────────┐
             │                   │  GitHub Actions      │
             │                   │  (self-hosted runner │
             │                   │   on your network)   │
             │                   └──────────┬──────────┘
             │                              │
             ▼                              ▼
      ┌────────────┐                ┌────────────┐
      │ nsci push  │                │ nsci deploy │
      │ (manual)   │                │ (automatic) │
      └──────┬─────┘                └──────┬─────┘
             │                              │
             ▼                              ▼
      ┌──────────────────────────────────────────┐
      │         gNMI Set Replace                  │
      │         NETCONF edit-config replace       │
      │         REST API PUT                      │
      └──────────────────┬───────────────────────┘
                         │
                         ▼
                  ┌──────────────┐
                  │   Devices     │
                  └──────────────┘
```

## What Happens When You Push

When you run `nsci push pe1-nyc`, here's exactly what happens:

### Step 1: Load the Config File

`nsci` reads `configs/pe1-nyc.json` — the full device config as a structured JSON object. This is an OpenConfig-modeled JSON tree with sections like `interfaces`, `network-instances`, `system`, `routing-policy`, etc.

### Step 2: Connect via gNMI

`nsci` opens a gRPC connection to the device on port 6030 (configurable per driver). Authentication is username/password from `inventory.yaml`.

### Step 3: gNMI Set with Replace

`nsci` sends a single gNMI `Set` request with the `replace` operation on the root path (`/`). The entire config JSON is the payload.

```
gNMI Set {
  replace: [
    {
      path: "/"
      val: <entire configs/pe1-nyc.json>
    }
  ]
}
```

### Step 4: The Device Reconciles

This is the key insight. The device receives the desired state and compares it to its current running config internally. It then:

- **Adds** anything in the payload that isn't in the running config
- **Removes** anything in the running config that isn't in the payload
- **Modifies** anything that exists in both but with different values
- **Leaves unchanged** anything that matches exactly

You never tell the device *how* to make the change. You declare *what* the config should look like. The device figures out the rest.

### Step 5: Response

The device returns success or failure. If successful, the running config now matches the JSON file exactly.

## Why Replace Instead of Merge?

gNMI and NETCONF both support two operations:

| Operation | Behavior |
|---|---|
| **Merge** | Add/update what you send, leave everything else untouched |
| **Replace** | Make the config look exactly like what you send, removing anything not present |

`nsci` uses **replace** because:

1. **Deletions are automatic.** Remove an NTP server from the JSON file → the device removes it. No need to generate `no ntp server` commands.
2. **Idempotent.** Push the same file twice and nothing changes. The device is already in the desired state.
3. **No state tracking.** You don't need to remember what was previously deployed. The file IS the desired state. Push it and the device matches.

The downside: you must manage the full config section you're replacing. If you replace `/system/ntp/servers` with two servers, any other servers on the device are removed. This is by design — the file is the source of truth.

## What About Multiple Devices?

### Independent Pushes

For unrelated changes to different devices, each push is independent:

```bash
nsci push pe1-nyc    # pushes pe1-nyc.json
nsci push pe2-nyc    # pushes pe2-nyc.json
```

These are separate gNMI calls to separate devices. No coordination.

### Parallel Deploy

For pushing to many devices at once:

```bash
nsci deploy pe1-nyc pe2-nyc pe3-chi pe4-dal --workers 10
```

This uses a thread pool to push to all devices simultaneously. The `--workers` flag controls how many concurrent connections.

### Atomic Deploy (Stacks)

For service deployments where devices must be consistent:

```bash
nsci stack-deploy l3vpn-cust-a
```

This reads `stacks/l3vpn-cust-a/stack.yaml` and executes a four-stage deploy:

```
Stage 1: Pre-flight
  Pull current config from ALL devices → save as rollback snapshots
  If any device is unreachable → ABORT (nothing touched)

Stage 2: Push
  Push new configs to ALL devices in parallel
  Track success/failure per device

Stage 3: Validate
  Pull config back from ALL successful devices
  Compare to expected state

Stage 4: Rollback (only if a device failed and atomic=true)
  Push rollback snapshots back to ALL devices
  Restore entire group to pre-change state
```

Either all devices get the change or none of them do.

## gNMI vs NETCONF vs REST API

`nsci` supports three transport protocols. The driver in `inventory.yaml` determines which one is used:

| Protocol | Config Format | Devices | How Replace Works |
|---|---|---|---|
| **gNMI** | JSON (OpenConfig) | Arista EOS, modern Cisco, Nokia | `Set` with `Replace` operation |
| **NETCONF** | XML (YANG models) | Cisco IOS-XR, Juniper Junos, Arista | `edit-config` with `operation="replace"` |
| **REST API** | JSON (vendor schema) | Palo Alto, F5, cloud APIs | `PUT` to resource endpoint |

The engineer's experience is the same regardless of protocol. Edit the JSON file, push, done. The driver handles the translation.

## Where Does the JSON Come From?

The first time you onboard a device, you pull its config:

```bash
nsci pull pe1-nyc
```

This connects to the device via gNMI `Get` (or NETCONF `get-config`) and saves the full running config as `configs/pe1-nyc.json`. From that point on, the file in the repo is the source of truth.

The JSON format is OpenConfig — a vendor-neutral YANG data model. The same JSON structure works across Arista, Cisco, Juniper, and Nokia devices (where OpenConfig is supported). Vendor-specific extensions appear as prefixed keys (e.g., `arista-rpol-augments:policy-type`).
