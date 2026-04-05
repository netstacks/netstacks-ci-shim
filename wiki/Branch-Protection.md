# Branch Protection

Branch protection prevents anyone from pushing config changes directly to `main`. Every change goes through a pull request with review and validation.

## Why This Matters

Without protection, any engineer can `git push` a config change to `main` and it deploys immediately. With 20 engineers, you get:
- No review before changes hit devices
- Concurrent changes that overwrite each other
- No audit trail of who approved what
- Accidental pushes deploying half-finished changes

## Setting Up Branch Protection

Go to your GitHub repo → **Settings** → **Branches** → **Add branch protection rule**.

**Branch name pattern:** `main`

### Recommended Rules

| Rule | Setting | Why |
|---|---|---|
| **Require a pull request before merging** | Enabled | Nobody pushes directly to main |
| **Required approvals** | 1 (or 2 for critical infra) | Someone reviews before it hits devices |
| **Dismiss stale pull request approvals** | Enabled | If you update the PR, previous approval is revoked |
| **Require status checks to pass** | Enabled | Preview workflow must succeed |
| **Require branches to be up to date** | Enabled | Must include latest main before merging |
| **Require conversation resolution** | Optional | All review comments must be resolved |
| **Do not allow bypassing** | Enabled | Even admins go through the process |

### The "Require Up to Date" Rule

This is the most important rule for multi-engineer teams. Here's what it prevents:

```
Without "require up to date":

  Engineer A branches from main, changes NTP on pe1-nyc
  Engineer B branches from main, changes BGP on pe1-nyc

  A merges → pe1-nyc.json has A's NTP change
  B merges → pe1-nyc.json has B's BGP change but LOST A's NTP change

  B's branch was based on the old pe1-nyc.json. It overwrote A's.
```

```
With "require up to date":

  Engineer A merges → pe1-nyc.json has A's NTP change
  Engineer B tries to merge → BLOCKED

  "This branch is out of date with main. Update your branch."

  B clicks "Update branch" → gets A's changes merged into their branch
  B's PR now has both A's NTP change and B's BGP change
  B merges → both changes preserved
```

## CODEOWNERS

For per-device approval requirements, add a `CODEOWNERS` file:

```
# Core routers — senior team approval required
configs/rr1-nyc.json     @netstacks/senior-network
configs/p1-nyc.json      @netstacks/senior-network
configs/p2-chi.json      @netstacks/senior-network

# PE routers — network team can approve
configs/pe*.json         @netstacks/network-team

# Customer devices — customer-ops team
configs/sw*.json         @netstacks/customer-ops
configs/ce*.json         @netstacks/customer-ops

# Inventory and infrastructure — senior only
inventory.yaml           @netstacks/senior-network
stacks/**                @netstacks/senior-network
library/**               @netstacks/platform-team
drivers/**               @netstacks/platform-team
```

With CODEOWNERS + branch protection:
- A junior engineer changing a customer switch needs customer-ops approval
- Changing a core P-router needs senior-network approval
- Changing a template or driver needs platform-team approval

## The Engineer's Experience

```
1. Create branch, edit config, push
2. Open PR
3. ┌─────────────────────────────────────────────┐
   │  PR: Update NTP on pe1-nyc                   │
   │                                               │
   │  ✓ Preview Changes — passed                   │
   │                                               │
   │  Review required: @netstacks/network-team     │
   │  ┌──────────────────────────────────────────┐ │
   │  │  Approve    Request changes    Comment   │ │
   │  └──────────────────────────────────────────┘ │
   │                                               │
   │  [Merge pull request]  ← only after approval  │
   └─────────────────────────────────────────────┘
4. Reviewer approves → engineer clicks Merge → CI deploys
```

No engineer bypasses review. No direct pushes to main. Every config change to every device goes through this process.
