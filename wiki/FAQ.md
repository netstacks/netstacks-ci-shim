# FAQ

## General

### What devices are supported?

Any device with a gNMI, NETCONF, or REST API. Currently tested: Arista EOS (gNMI), Cisco IOS-XR (NETCONF), Palo Alto (REST API driver ready). CLI-only devices (classic IOS, ASA) are not supported by design. See [[Supported Platforms]].

### Can I use this without Git/GitHub?

Yes. `nsci pull`, `nsci push`, `nsci diff`, `nsci validate` all work standalone. Git is for history and collaboration. GitHub Actions is for automation. Both are optional.

### Can I use this with GitLab instead of GitHub?

Yes. The `nsci` tool itself has no GitHub dependency. The CI workflows would need to be rewritten as `.gitlab-ci.yml` files, and the runner setup is different (GitLab Runner instead of GitHub Actions runner), but the core tool works the same.

### How is this different from Ansible?

Ansible generates CLI commands and pushes them via SSH. It requires knowing vendor-specific syntax and handling ordering, idempotency, and rollback yourself.

NetStacks CI declares desired state as structured JSON and uses gNMI/NETCONF replace operations. The device handles syntax, ordering, and reconciliation. No CLI commands, no SSH, no command generation.

### How is this different from Terraform for networking?

Terraform uses providers that make individual API calls (create resource, update resource, delete resource). Each change is imperative — Terraform decides what to add and remove.

NetStacks CI uses a single replace operation. You push the entire desired state and the device reconciles. It's closer to Kubernetes declarative management than Terraform's plan/apply model.

### How is this different from NSO?

NSO uses YANG models, a Java transaction engine, proprietary NEDs, and a custom database (CDB). It's an enterprise product with complex licensing.

NetStacks CI uses the same structured data models (OpenConfig/YANG) but relies on the device's native gNMI/NETCONF implementation for reconciliation instead of building a custom diff engine. Config is stored as files in Git instead of CDB. It's open source and has no runtime beyond Python.

### Does this replace NetStacks (the product)?

No. NetStacks CI is the open-source engine. NetStacks (the product) wraps it with a UI: template browser, deploy wizard, history timeline, credential vault, RBAC. Engineers who don't want to use Git directly use NetStacks. The underlying push/pull/validate logic is the same.

## Config Management

### The JSON files are huge. How do I find what I need?

Use `nsci show`:

```bash
nsci show pe1-nyc                    # overview of sections
nsci show pe1-nyc system/ntp         # drill into NTP
nsci show pe1-nyc interfaces         # see interfaces
```

This presents the JSON as a readable tree without opening the file.

### Can two stacks configure the same device?

Yes. A device can be in multiple stacks. The config file is always the full device config — stacks just control deployment behavior (which devices deploy together and whether it's atomic).

### What happens if I edit the config file wrong?

If the JSON is malformed, `nsci push` will fail before touching the device. If the JSON is valid but contains bad config (e.g., invalid IP address), the device's gNMI/NETCONF validation will reject it and return an error.

### What happens if someone changes the device manually?

The device drifts from the config file. `nsci validate` detects this. You then choose:
- `nsci push` to overwrite the manual change (enforce the file)
- `nsci pull` to accept the manual change (update the file)

### Can I manage only part of the device config?

The current model is full-device config replace. This is the safest approach — the file IS the complete desired state. Partial config management (only NTP, only BGP) is possible with gNMI by replacing subtrees instead of root, but this isn't exposed in the CLI yet.

## CI/CD

### Do I need GitHub Actions to use this?

No. You can run all commands manually. GitHub Actions automates the preview-on-PR and deploy-on-merge workflow. See [[GitHub Actions Setup]].

### Why does the runner need to be on my network?

The runner pushes config to devices via gNMI/NETCONF. It needs network access to the devices (port 6030 for gNMI, port 830 for NETCONF). GitHub's cloud runners can't reach your devices.

### What if two PRs merge at the same time?

The deploy workflow has `concurrency: group: deploy` which ensures only one deploy runs at a time. The second merge queues until the first finishes.

### What if a deploy fails mid-way through multiple devices?

If the stack is `atomic: true`, all devices roll back to their pre-change state. If `atomic: false`, successful devices keep their changes and failed devices are reported. See [[Stacks and Atomic Deploys]].

## Security

### Credentials are in inventory.yaml — isn't that insecure?

Yes. Inline credentials are for development and testing only. In production, use vault references:

```yaml
credential: vault://network/pe1-nyc
```

The `nsci` tool can be extended with vault integration (HashiCorp Vault, NetStacks credential vault, AWS Secrets Manager, etc.).

### Can someone deploy without approval?

With branch protection enabled on `main`, no. Every config change requires a PR and at least one reviewer's approval. CODEOWNERS can enforce that specific teams approve changes to specific devices. See [[Branch Protection]].

### Is the gNMI connection encrypted?

gNMI uses gRPC which supports TLS. In production, enable TLS on devices and configure the driver accordingly. In lab environments, `insecure: true` disables certificate verification.
