# History and Rollback

Every change to a device config is a Git commit. `nsci` provides commands to browse this history and rollback without knowing Git.

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

Shows the diff for version 0 (the most recent change) with color-coded lines:
- Green = lines added
- Red = lines removed

## Rolling Back

### Emergency: Fix the Device Now

```bash
nsci rollback pe1-nyc 1 --push
```

This does two things:
1. Restores `configs/pe1-nyc.json` to version 1
2. Pushes the old config to the device via gNMI — **device is fixed immediately**

```
Rolling back pe1-nyc to version 1:
  60c1dc1  1 hour ago  Update BGP neighbor config

  Changes: +12 lines, -47 lines
  Restored configs/pe1-nyc.json to version 1
  Committed: Rollback pe1-nyc to version 1 (60c1dc1)

Pushing rollback to pe1-nyc...
  PUSHED to device — pe1-nyc restored to version 1
```

**The device is fixed.** That's what matters in an emergency.

The Git repo still has the bad change on `main`. You fix that separately — see [Syncing Git After a Rollback](#syncing-git-after-a-rollback) below.

### Non-Emergency: Review Before Applying

```bash
nsci rollback pe1-nyc 1
```

Restores the file locally without touching the device. Review it, then push when ready:

```bash
nsci show pe1-nyc system/ntp     # check it looks right
nsci push pe1-nyc                # push to device
```

### Rollback History is Preserved

After a rollback, the history shows both the original change and the rollback:

```
  0: abc1234  just now    Rollback pe1-nyc to version 2 (c6b2820)  (current)
  1: 67ceb93  5 min ago   Add NTP server 10.0.0.99
  2: 60c1dc1  1 hour ago  Update BGP neighbor config
  3: c6b2820  3 days ago  Initial pull from NetBox
```

You can always see what happened and even rollback a rollback.

## Syncing Git After a Rollback

`nsci rollback --push` fixes the device instantly. But `main` on GitHub still has the bad change. The device and the repo are now out of sync. You need to fix the repo so CI doesn't redeploy the bad config.

**Two options:**

### Option A: Pull the device state into a PR

The device is now correct (you just rolled it back). Pull its current config and push to main:

```bash
nsci pull pe1-nyc                          # get current (rolled-back) state from device
git checkout -b fix/rollback-pe1-nyc       # create a branch
git add configs/pe1-nyc.json
git commit -m "Sync pe1-nyc after emergency rollback"
git push -u origin fix/rollback-pe1-nyc    # push branch, open PR, merge
```

This is the cleanest approach. The repo now matches the device.

### Option B: Revert the bad commit on GitHub

Find the bad merge commit on GitHub and click "Revert" on the PR page. This creates a new PR that undoes the change. Merge it. CI deploys — but the device already has the right config, so the deploy is a no-op.

### Why Not Auto-Push to Git?

We deliberately don't auto-push to `main` because:
- Branch protection blocks direct pushes (this is correct and should stay)
- Auto-creating rollback branches that trigger CI on merge would re-deploy and potentially cause confusion
- The device is the priority — fix the device first, fix the paperwork second

## Emergency Rollback Workflow (Complete)

```bash
# 1. Something broke. Fix the device.
nsci rollback pe1-nyc 1 --push

# 2. Verify it's fixed.
nsci validate pe1-nyc

# 3. When things are calm, sync the repo.
nsci pull pe1-nyc
git checkout -b fix/rollback-pe1-nyc
git add configs/pe1-nyc.json
git commit -m "Sync pe1-nyc after emergency rollback"
git push -u origin fix/rollback-pe1-nyc
# Open PR, merge.
```

Steps 1-2: 30 seconds, device is fixed.
Step 3: whenever you have time, no urgency.

## Multi-Device Rollback

```bash
# Fix all devices
nsci rollback pe1-nyc 1 --push
nsci rollback pe2-nyc 1 --push
nsci rollback ce1-nyc-globalbank 1 --push

# Verify
nsci validate pe1-nyc
nsci validate pe2-nyc

# Sync repo later
for device in pe1-nyc pe2-nyc ce1-nyc-globalbank; do
  nsci pull "$device"
done
git checkout -b fix/rollback-l3vpn-cust-a
git add configs/
git commit -m "Sync after L3VPN rollback — BGP sessions not establishing"
git push -u origin fix/rollback-l3vpn-cust-a
```
