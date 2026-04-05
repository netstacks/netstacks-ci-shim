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

### Rollback the File Only

```bash
nsci rollback pe1-nyc 1
```

This restores `configs/pe1-nyc.json` to version 1 and creates a new Git commit. The device is **not** changed yet. You can:

- Review the rolled-back file
- `nsci push pe1-nyc` to apply it manually
- `git push` to trigger CI auto-deploy

### Rollback and Push Immediately

```bash
nsci rollback pe1-nyc 1 --push
```

Restores the file, commits it, AND pushes to the device in one step. Use this when you know you want to revert and apply immediately.

```
Rolling back pe1-nyc to version 1:
  60c1dc1  1 hour ago  Update BGP neighbor config

  Changes: +12 lines, -47 lines
  Restored configs/pe1-nyc.json to version 1
  Committed: Rollback pe1-nyc to version 1 (60c1dc1)

Pushing rollback to pe1-nyc...
  PUSHED — pe1-nyc restored to version 1
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

# 2. Rollback to the last known good version and push immediately
nsci rollback pe1-nyc 1 --push

# 3. Verify the device is back to normal
nsci validate pe1-nyc

# 4. Push the git commit so CI and the repo are in sync
git push
```

Total time: under 30 seconds. No SSH, no remembering what the old config was, no manual CLI commands.

## Multi-Device Rollback

If a stack deploy went wrong and the automatic rollback didn't catch it (e.g., the deploy succeeded but the service is broken):

```bash
# Rollback each device in the stack
nsci rollback pe1-nyc 1 --push
nsci rollback pe2-nyc 1 --push
nsci rollback ce1-nyc-globalbank 1 --push

# Commit all rollbacks
git add configs/
git commit -m "Rollback l3vpn-cust-a — BGP sessions not establishing"
git push
```
