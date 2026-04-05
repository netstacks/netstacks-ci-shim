# Config Diffs

The `nsci diff` command compares your local config file against the live device. This tells you exactly what would change if you pushed.

## Basic Usage

```bash
nsci diff pe1-nyc
```

### No Differences

```
pe1-nyc: no differences (file matches device)
```

The device matches your file exactly. Nothing would change if you pushed.

### Differences Found

```
pe1-nyc: differences found

  values_changed:
    root['openconfig-system:system']['ntp']['servers']['server'][2]['address']:
      old: '10.0.0.3'
      new: '10.0.0.4'

  iterable_item_added:
    root['openconfig-system:system']['ntp']['servers']['server'][3]:
      {'address': '10.0.0.5', 'config': {'address': '10.0.0.5'}}
```

This shows:
- NTP server at index 2 changed from 10.0.0.3 to 10.0.0.4
- A new NTP server (10.0.0.5) was added at index 3

## What the Diff Tells You

| Change Type | Meaning |
|---|---|
| `values_changed` | A field has a different value in your file vs the device |
| `iterable_item_added` | Something in your file that doesn't exist on the device (will be added on push) |
| `iterable_item_removed` | Something on the device that's not in your file (will be removed on push) |
| `dictionary_item_added` | A new config section in your file |
| `dictionary_item_removed` | A config section on the device that's not in your file |
| `type_changes` | A field changed type (e.g., string to number) |

## How It Works

1. `nsci` reads `configs/pe1-nyc.json` (your local file)
2. `nsci` connects to the device via gNMI and pulls the current running config
3. `nsci` performs a deep JSON comparison between the two
4. Differences are reported with their full path in the JSON tree

The comparison uses the `deepdiff` library which understands nested JSON structures, lists, and type differences.

## Common Scenarios

### You edited the file and want to preview before pushing

```bash
vim configs/pe1-nyc.json        # make your change
nsci diff pe1-nyc               # see what would change on the device
nsci push pe1-nyc               # push if the diff looks right
```

### Someone changed the device manually (drift detection)

```bash
nsci diff pe1-nyc
```

If you haven't changed the file but `diff` shows differences, someone (or something) modified the device outside of `nsci`. You can:

- `nsci push pe1-nyc` — overwrite the manual change with your file
- `nsci pull pe1-nyc` — accept the manual change into your file

### Checking multiple devices

```bash
for device in pe1-nyc pe2-nyc pe3-chi; do
    echo "=== $device ==="
    nsci diff "$device"
    echo
done
```

## Diff vs Validate

| Command | What It Does | Output |
|---|---|---|
| `nsci diff` | Detailed comparison | Full list of every difference |
| `nsci validate` | Quick check | Just "IN SYNC" or "DRIFT" |

Use `validate` for quick checks (CI, monitoring). Use `diff` when you need to understand what's different.

## In CI (Pull Request Preview)

The `preview.yaml` workflow runs `nsci diff` for every changed device and posts the results to the PR summary. Reviewers see exactly what will change on each device before approving the merge.
