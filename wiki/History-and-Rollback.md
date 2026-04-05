# History and Rollback

Every change to a device config is a Git commit. `nsci` provides commands to browse history and rollback.

## Viewing History

```bash
nsci history pe1-nyc
```

```
History for pe1-nyc:

  0: 67ceb93  2 min ago   Add NTP server 10.0.0.99          (current)
  1: 60c1dc1  1 hour ago  Update BGP neighbor config
  2: c6b2820  3 days ago  Initial pull from NetBox

To rollback: nsci rollback pe1-nyc <number>
To see diff: nsci history pe1-nyc --diff <number>
```

Version 0 is always the current config. Higher numbers are older versions.

## Viewing What Changed

```bash
nsci history pe1-nyc --diff 0
```

Shows the diff for version 0 (the most recent change) with color-coded additions (green) and removals (red).

## Rollback: Two Modes

How you rollback depends on whether your team uses CI or not. Pick one mode — don't mix them.

---

### Manual Mode (No CI)

You run `nsci` directly from your laptop. You push to devices yourself. No PRs, no branches, no CI.

**Rollback:**

```bash
# See history
nsci history pe1-nyc

# Restore file AND push to device in one step
nsci rollback pe1-nyc 1 --push
```

```
Rolling back pe1-nyc to version 1:
  60c1dc1  1 hour ago  Update BGP neighbor config

  Changes: +12 lines, -47 lines
  Restored configs/pe1-nyc.json to version 1
  Committed: Rollback pe1-nyc to version 1 (60c1dc1)

Pushing rollback to pe1-nyc...
  PUSHED to device — pe1-nyc restored to version 1
```

Done. Device is fixed. Local Git history tracks the rollback. No remote repo involved.

---

### CI Mode (GitHub Actions)

Engineers never push to devices directly. All device pushes go through CI on merge to `main`. `main` is protected — nobody pushes to it directly. Everything goes through branches and PRs.

**Rollback:**

```bash
# Create a branch (never work on main)
git checkout -b rollback-pe1-nyc

# Restore the file (no --push, file only)
nsci rollback pe1-nyc 1

# Commit and push the branch
git add configs/pe1-nyc.json
git commit -m "Rollback pe1-nyc — BGP sessions down"
git push -u origin rollback-pe1-nyc

# Open PR on GitHub → reviewer approves → merge
# CI deploys the rolled-back config to the device
```

The device gets fixed when the PR merges and CI runs `nsci deploy pe1-nyc`. The rollback goes through the same review process as any other change.

**Emergency rollback (CI mode, can't wait for PR review):**

If the network is down and you can't wait for approval, bypass CI temporarily:

```bash
# Fix the device directly (emergency)
nsci rollback pe1-nyc 1 --push

# Device is fixed. Now sync the repo through normal process.
nsci pull pe1-nyc                          # pull current device state
git checkout -b emergency-rollback-pe1
git add configs/pe1-nyc.json
git commit -m "Emergency rollback pe1-nyc — sync after direct push"
git push -u origin emergency-rollback-pe1
# Open PR, merge (CI deploy is a no-op since device already matches)
```

The `--push` bypasses CI to fix the device immediately. The PR after is just to get `main` back in sync. CI will deploy on merge, but since the device already has the right config, it's a no-op.

---

## Which Mode Am I In?

| | Manual Mode | CI Mode |
|---|---|---|
| **Who pushes to devices** | You (`nsci push`, `nsci rollback --push`) | CI only (`nsci deploy` in GitHub Actions) |
| **main branch** | You commit directly | Protected, PRs only |
| **Rollback** | `nsci rollback 1 --push` | `nsci rollback 1` → branch → PR → merge → CI deploys |
| **Emergency rollback** | Same as normal | `nsci rollback 1 --push` (bypass CI, sync repo after) |
| **Team size** | 1-2 engineers | Any size |
| **Audit trail** | Local git log | GitHub PRs with reviews |

Most teams start in Manual Mode and move to CI Mode when they're comfortable with Git.

## Rollback History is Preserved

After a rollback, the history shows both the original change and the rollback:

```
  0: abc1234  just now    Rollback pe1-nyc to version 2 (c6b2820)  (current)
  1: 67ceb93  5 min ago   Add NTP server 10.0.0.99
  2: 60c1dc1  1 hour ago  Update BGP neighbor config
  3: c6b2820  3 days ago  Initial pull from NetBox
```

The rollback is a new commit. You can always see what happened and even rollback a rollback.

## Multi-Device Rollback

### Manual Mode

```bash
nsci rollback pe1-nyc 1 --push
nsci rollback pe2-nyc 1 --push
nsci rollback ce1-nyc-globalbank 1 --push
```

### CI Mode

```bash
git checkout -b rollback-l3vpn-cust-a
nsci rollback pe1-nyc 1
nsci rollback pe2-nyc 1
nsci rollback ce1-nyc-globalbank 1
git add configs/
git commit -m "Rollback L3VPN Cust A — BGP not establishing"
git push -u origin rollback-l3vpn-cust-a
# Open PR, merge, CI deploys all three
```
