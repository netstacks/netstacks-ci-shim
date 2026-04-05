# Stacks and Atomic Deploys

## What Is a Stack?

A stack groups devices that should deploy together. When a service spans multiple devices — an L3VPN across PE and CE routers, a routing policy across route reflectors — a stack ensures either all devices get the change or none of them do.

## Creating a Stack

Create a directory under `stacks/` with a `stack.yaml` file:

```yaml
# stacks/l3vpn-cust-a/stack.yaml
name: l3vpn-cust-a
description: L3VPN service for Customer A
atomic: true
devices:
  - pe1-nyc
  - pe2-nyc
  - ce1-nyc-globalbank
```

### Fields

| Field | Required | Description |
|---|---|---|
| `name` | yes | Stack identifier |
| `description` | no | Human-readable description |
| `atomic` | yes | `true` = all-or-nothing, `false` = independent per device |
| `devices` | yes | List of device names from inventory |
| `workers` | no | Parallel threads (default: 10) |

## Atomic vs Non-Atomic

### Atomic (`atomic: true`)

Use for **services** — config that must be consistent across devices.

```
L3VPN needs: PE1 config + PE2 config + CE1 config
If CE1 fails → PE1 and PE2 roll back → network stays consistent
```

If any device in the stack fails to push or validate, ALL devices get restored to their pre-change state. This prevents a half-deployed service.

### Non-Atomic (`atomic: false`)

Use for **baselines** — independent config that doesn't depend on other devices.

```
NTP change on 9 devices
If device 5 fails → devices 1-4 and 6-9 keep their NTP change
Device 5 is reported as failed, you investigate separately
```

Each device succeeds or fails independently. One failure doesn't affect the others.

## Deploying a Stack

```bash
nsci stack-deploy l3vpn-cust-a
```

### The Four Stages

```
Stage 1: Pre-flight
  ┌─────────┐  ┌─────────┐  ┌──────────────┐
  │ PE1-NYC │  │ PE2-NYC │  │ CE1-GLOBALBANK│
  │  pull   │  │  pull   │  │    pull       │
  │ config  │  │ config  │  │   config      │
  └────┬────┘  └────┬────┘  └──────┬────────┘
       │            │              │
       ▼            ▼              ▼
    [snapshot]   [snapshot]     [snapshot]     ← saved in memory for rollback
    
  If ANY device is unreachable → ABORT. Nothing touched.


Stage 2: Push (parallel)
  ┌─────────┐  ┌─────────┐  ┌──────────────┐
  │ PE1-NYC │  │ PE2-NYC │  │ CE1-GLOBALBANK│
  │  push   │  │  push   │  │    push       │
  │  new    │  │  new    │  │    new        │
  │ config  │  │ config  │  │   config      │
  └────┬────┘  └────┬────┘  └──────┬────────┘
       │            │              │
       ✓            ✓              ✗ FAILED


Stage 3: Validate (successful devices only)
  PE1-NYC: IN SYNC ✓
  PE2-NYC: IN SYNC ✓


Stage 4: Rollback (because CE1 failed and atomic=true)
  ┌─────────┐  ┌─────────┐  ┌──────────────┐
  │ PE1-NYC │  │ PE2-NYC │  │ CE1-GLOBALBANK│
  │  push   │  │  push   │  │  (was never   │
  │ snapshot│  │ snapshot│  │   changed)    │
  └─────────┘  └─────────┘  └──────────────┘
  
  All devices back to pre-change state.
  DEPLOY FAILED.
```

### Output

```
Deploy to 3 devices (workers=3, atomic=True)
  Devices: pe1-nyc, pe2-nyc, ce1-nyc-globalbank

Stage 1: Pre-flight (saving rollback snapshots)...
  pe1-nyc: OK (snapshot saved)
  pe2-nyc: OK (snapshot saved)
  ce1-nyc-globalbank: OK (snapshot saved)

Stage 2: Pushing configs...
  pe1-nyc: PUSHED
  pe2-nyc: PUSHED
  ce1-nyc-globalbank: FAILED — connection timeout

Stage 3: Validating...
  pe1-nyc: IN SYNC
  pe2-nyc: IN SYNC

Stage 4: ROLLING BACK (1 failures, atomic mode)
  Restoring all 3 devices to pre-flight state...
  pe1-nyc: ROLLED BACK
  pe2-nyc: ROLLED BACK
  ce1-nyc-globalbank: ROLLBACK FAILED (MANUAL INTERVENTION NEEDED)

DEPLOY FAILED — all devices rolled back to previous state.
```

## Stacks in CI

When a PR changes `configs/pe1-nyc.json` and merges, the CI workflow checks if PE1-NYC belongs to any stack. If it does, the entire stack deploys — not just PE1.

This means: editing one device in a stack triggers deployment of all devices in that stack. This is intentional. If PE1's config changed, the full L3VPN should be validated as a unit.

## Listing Stacks

```bash
nsci stack-list
```

```
Stack                     Atomic     Devices  Description
--------------------------------------------------------------------------------
baseline-ntp              no         9        NTP server standardization
l3vpn-cust-a              yes        3        L3VPN service for Customer A
```

## Ad-Hoc Multi-Device Deploy

You don't need a stack for one-time multi-device operations:

```bash
# Atomic (default)
nsci deploy pe1-nyc pe2-nyc pe3-chi

# Non-atomic
nsci deploy pe1-nyc pe2-nyc pe3-chi --no-atomic

# More parallelism
nsci deploy pe1-nyc pe2-nyc pe3-chi --workers 20
```

The difference: stacks are saved as files in the repo (permanent, CI-aware). Ad-hoc deploys are one-time commands.
