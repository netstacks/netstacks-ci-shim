# GitHub Actions Setup

NetStacks CI includes two GitHub Actions workflows that automate preview and deploy. These are optional — you can use `nsci` manually without CI.

## How It Works

```
Engineer edits config file
       │
       ▼
   git push → opens PR
       │
       ▼
┌──────────────────────────┐
│  preview.yaml            │  ← Runs on PR
│  Connects to devices     │
│  Shows config diff       │
│  Posts results to PR     │
└──────────────────────────┘
       │
   Reviewer approves → merge to main
       │
       ▼
┌──────────────────────────┐
│  deploy.yaml             │  ← Runs on merge
│  Detects changed devices │
│  Checks stack membership │
│  Deploys (atomic if stack)│
│  Validates post-deploy   │
└──────────────────────────┘
```

## Requirements

1. **A self-hosted runner** on your network (see [[Self-Hosted Runner]])
2. **Branch protection** on `main` (see [[Branch Protection]])
3. **Python 3.10+ and dependencies** installed on the runner

## The Workflows

### Preview (preview.yaml)

**Triggers:** When a PR is opened or updated that touches `configs/`.

**What it does:**
1. Detects which device config files changed
2. Runs `nsci diff` for each changed device
3. Posts the diff results to the PR summary

**Why:** Reviewers can see exactly what will change on each device before approving the merge.

```yaml
# .github/workflows/preview.yaml
name: Preview Changes

on:
  pull_request:
    branches: [main]
    paths: ["configs/**"]

jobs:
  preview:
    runs-on: [self-hosted, network]
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }

      - name: Detect changed devices
        id: detect
        run: |
          devices=$(git diff --name-only origin/main...HEAD -- configs/ \
            | sed 's|configs/||;s|\.json||' | sort -u)
          echo "devices=$devices" >> $GITHUB_OUTPUT

      - name: Preview diffs
        run: |
          for device in ${{ steps.detect.outputs.devices }}; do
            echo "### $device" >> $GITHUB_STEP_SUMMARY
            python3 nsci diff "$device" 2>&1 >> $GITHUB_STEP_SUMMARY
          done
```

### Deploy (deploy.yaml)

**Triggers:** When `configs/` files change on `main` (PR merged or direct push).

**What it does:**
1. Detects which device config files changed
2. Checks if any changed device belongs to a stack
3. If yes: runs `nsci stack-deploy` (respects atomic setting)
4. If no: runs `nsci push` for each independent device

**Concurrency:** Only one deploy runs at a time. Subsequent merges queue.

```yaml
# .github/workflows/deploy.yaml
name: Deploy to Devices

on:
  push:
    branches: [main]
    paths: ["configs/**"]

concurrency:
  group: deploy
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: [self-hosted, network]
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 2 }

      - name: Detect and deploy
        run: |
          changed=$(git diff --name-only HEAD~1 HEAD -- configs/ \
            | sed 's|configs/||;s|\.json||' | sort -u)

          # Deploy via stacks if applicable, otherwise independent push
          for stack_dir in stacks/*/; do
            [ -f "${stack_dir}stack.yaml" ] || continue
            stack_name=$(basename "$stack_dir")
            # ... checks if changed devices belong to this stack
            # ... runs nsci stack-deploy if they do
          done
          # Remaining devices get independent push
```

See the full workflow file for the complete stack-detection logic.

## What Engineers See

### On the PR

```
Config Preview

### pe1-nyc
pe1-nyc: differences found
  values_changed:
    system.ntp.servers.server[2].address: 10.0.0.3 → 10.0.0.4
```

### After Merge

In the Actions tab:

```
Deploy to Devices
  ✓ Detect and deploy
    Changed devices: pe1-nyc
    === Stack: l3vpn-cust-a ===
    Deploy to 3 devices (workers=3, atomic=True)
    Stage 1: Pre-flight ... OK
    Stage 2: Pushing ... OK
    Stage 3: Validating ... OK
    DEPLOY SUCCEEDED — 3 devices updated.
```

## Disabling CI

If you don't want automated deploys, simply delete the workflow files:

```bash
rm -rf .github/workflows/
git commit -m "Remove CI workflows"
git push
```

All `nsci` commands still work manually. CI is a convenience layer, not a requirement.
