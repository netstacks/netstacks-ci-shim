# CODEOWNERS

CODEOWNERS is a GitHub feature that automatically requests reviews from specific teams or people when certain files are changed in a PR. Combined with branch protection, it enforces that the right people approve changes to the right devices.

## The File

`CODEOWNERS` lives in the root of the repo:

```
# Core routers — senior network team must approve
configs/rr1-nyc.json     @netstacks/senior-network
configs/p1-nyc.json      @netstacks/senior-network
configs/p2-chi.json      @netstacks/senior-network
configs/p3-ams.json      @netstacks/senior-network

# PE routers — network team can approve
configs/pe*.json         @netstacks/network-team

# Customer devices — customer-ops team
configs/sw*.json         @netstacks/customer-ops
configs/ce*.json         @netstacks/customer-ops

# Inventory changes — senior only
inventory.yaml           @netstacks/senior-network

# Stacks — senior only (controls atomic deploy behavior)
stacks/**                @netstacks/senior-network

# Templates and drivers — platform team
library/**               @netstacks/platform-team
drivers/**               @netstacks/platform-team
```

## How It Works

When an engineer opens a PR that modifies `configs/pe1-nyc.json`, GitHub automatically:

1. Checks CODEOWNERS for matching patterns
2. `configs/pe*.json` matches → `@netstacks/network-team` is the owner
3. Requests a review from `@netstacks/network-team`
4. The PR cannot be merged until someone from that team approves

## Pattern Syntax

| Pattern | Matches |
|---|---|
| `configs/pe1-nyc.json` | Exactly that file |
| `configs/pe*.json` | All PE router configs |
| `configs/*.json` | All device configs |
| `stacks/**` | Everything under stacks/ (recursive) |
| `library/**` | Everything under library/ (recursive) |

## Example Scenarios

### Junior engineer changes a customer switch

```
PR: Update VLAN config on sw1-chi-techcorp

Files: configs/sw1-chi-techcorp.json

Matched rule: configs/sw*.json → @netstacks/customer-ops
Required reviewer: customer-ops team

→ Customer-ops approves. Merged. Deployed.
```

### Engineer changes a core P-router

```
PR: Update ISIS metric on p1-nyc

Files: configs/p1-nyc.json

Matched rule: configs/p1-nyc.json → @netstacks/senior-network
Required reviewer: senior-network team

→ Senior engineer reviews carefully. Approves. Merged. Deployed.
```

### Engineer changes a PE router that's in a stack

```
PR: Update BGP neighbor on pe1-nyc

Files: configs/pe1-nyc.json

Matched rule: configs/pe*.json → @netstacks/network-team
Required reviewer: network-team

→ Network team approves.
→ CI detects pe1-nyc is in stack l3vpn-cust-a.
→ Full stack deploys atomically (pe1-nyc + pe2-nyc + ce1-nyc).
```

### Someone tries to modify a template

```
PR: Update NTP template

Files: library/ntp/template.xml.j2

Matched rule: library/** → @netstacks/platform-team
Required reviewer: platform-team only

��� Random engineer cannot modify templates without platform team review.
```

## Setup

1. Create the `CODEOWNERS` file in the repo root
2. In GitHub → Settings → Branches → Branch protection for `main`:
   - Enable "Require review from Code Owners"
3. Create the GitHub teams referenced in the file:
   - `@netstacks/senior-network`
   - `@netstacks/network-team`
   - `@netstacks/customer-ops`
   - `@netstacks/platform-team`

## Tips

- **More specific rules override less specific ones.** Put specific file rules after wildcard rules.
- **Multiple owners** can be listed: `configs/rr1-nyc.json @alice @bob @netstacks/senior-network`
- **Individual users** work too: `configs/rr1-nyc.json @senior-engineer-alice`
- **The last matching pattern wins.** Order matters.
