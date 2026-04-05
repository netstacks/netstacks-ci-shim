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

### Rollback and Push Immediately

```bash
nsci rollback pe1-nyc 1 --push
```

This does everything in one command:
1. Restores the config file to version 1
2. Creates a Git commit
3. Pushes the old config to the device via gNMI (device is fixed immediately)
4. Pushes the Git commit so the repo stays in sync

```
Rolling back pe1-nyc to version 1:
  60c1dc1  1 hour ago  Update BGP neighbor config

  Changes: +12 lines, -47 lines
  Restored configs/pe1-nyc.json to version 1
  Committed: Rollback pe1-nyc to version 1 (60c1dc1)

Pushing rollback to pe1-nyc...
  PUSHED to device — pe1-nyc restored to version 1
  PUSHED to Git — repo is in sync
```

**No `git commit`, no `git push`, no branch management.** One command.

### What Happens With Branch Protection

If `main` has branch protection (which it should — see [[Branch Protection]]), direct pushes to `main` are blocked. `nsci` handles this automatically:

1. The device gets the rollback immediately (gNMI push happens first)
2. `nsci` tries `git push` to the current branch
3. If blocked, it creates a `rollback/pe1-nyc-<timestamp>` branch and pushes there
4. You merge the rollback branch into `main` via PR (the device is already fixed)

```
  PUSHED to device — pe1-nyc restored to version 1
  PUSHED to Git branch: rollback/pe1-nyc-1775316537
  Open a PR to merge the rollback into main.
```

**The device is fixed first, the paperwork follows.** In an emergency, the device is what matters. The Git history catches up when you merge the rollback PR.

### Rollback the File Only (No Device Push)

```bash
nsci rollback pe1-nyc 1
```

Restores the config file locally without touching the device or Git remote. Use this when you want to review before applying:

```
Config file rolled back (local only). Next steps:
  nsci push pe1-nyc       ← apply to device now
  git push                ← sync repo (CI will deploy)
```

### Rollback History is Preserved

After a rollback, the history shows both the original change and the rollback:

```bash
nsci history pe1-nyc
```

```
  0: abc1234  just now    Rollback pe1-nyc to version 2 (c6b2820)  (current)
  1: 67ceb93  5 min ago   Add NTP server 10.0.0.99
  2: 60c1dc1  1 hour ago  Update BGP neighbor config
  3: c6b2820  3 days ago  Initial pull from NetBox
```

The rollback is a new commit, not a rewrite of history. You can always see what happened and even rollback a rollback.

## Emergency Rollback Workflow

Something broke. BGP sessions are down. You need to revert NOW.

```bash
# 1. See what changed recently
nsci history pe1-nyc

# 2. Rollback, push to device AND Git — one command
nsci rollback pe1-nyc 1 --push

# 3. Verify the device is back to normal
nsci validate pe1-nyc
```

Three commands, under 30 seconds. The device is fixed at step 2. Step 3 is verification.

If branch protection is on, the Git push creates a rollback branch. Merge the PR later when things are calm. The device is already restored.

## Multi-Device Rollback

If a stack deploy went wrong and the automatic rollback didn't catch it:

```bash
nsci rollback pe1-nyc 1 --push
nsci rollback pe2-nyc 1 --push
nsci rollback ce1-nyc-globalbank 1 --push
```

Each command restores one device and syncs Git. All three devices are fixed independently.

## Rollback With Review (Non-Emergency)

When you have time and want to be careful:

```bash
# See history
nsci history pe1-nyc

# Check what version 2 looked like
nsci history pe1-nyc --diff 2

# Rollback file only (no device push)
nsci rollback pe1-nyc 2

# Review what you're about to push
nsci show pe1-nyc system/ntp

# Happy with it? Push to device
nsci push pe1-nyc

# Sync to Git
git push
```
