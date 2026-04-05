# Browsing Configs

Device config files are large — 3,000+ lines of JSON. The `nsci show` command lets you browse them without opening the raw file.

## Overview of a Device

```bash
nsci show pe1-nyc
```

```
pe1-nyc config sections:

  acl/
    acl-sets
  
  interfaces/
    interface

  network-instances/
    network-instance

  routing-policy/
    defined-sets
    policy-definitions

  system/
    aaa
    clock
    config
    grpc-servers
    logging
    ntp
    ssh-server
```

This shows the top-level sections and their immediate children. Every EOS/XR/Junos device follows the same OpenConfig structure.

## Drilling Into Sections

Add a path to drill deeper. Use `/` to navigate:

```bash
nsci show pe1-nyc system/ntp
```

```
servers:
  server:
    address: 10.0.0.1
    config:
      address: 10.0.0.1
    ---
    address: 10.0.0.2
    config:
      address: 10.0.0.2
      prefer: True
    ---
```

Each `---` separator is an entry in a list.

## Common Paths

| What You Want | Path |
|---|---|
| NTP servers | `system/ntp` |
| Hostname and system config | `system/config` |
| All interfaces | `interfaces` |
| A specific interface | `interfaces/Ethernet1` |
| BGP config | `network-instances/default/protocols` |
| Route-maps and policy | `routing-policy/policy-definitions` |
| Community lists | `routing-policy/defined-sets` |
| ACLs | `acl/acl-sets` |
| LLDP | `lldp` |

## Navigating Lists

When a section contains a list (like interfaces or BGP neighbors), you can navigate by the item's name or address:

```bash
# List all interfaces
nsci show pe1-nyc interfaces
```

```
interface:
  - Ethernet1
  - Ethernet2
  - Loopback0
  - Management0
```

```bash
# Show a specific interface
nsci show pe1-nyc interfaces/Loopback0
```

```
config:
  description: Management Loopback
  mtu: 0
  name: Loopback0
  type: iana-if-type:softwareLoopback
subinterfaces:
  subinterface:
    config:
      description: Management Loopback
    index: 0
    ipv4:
      addresses:
        address:
          config:
            ip: 10.255.0.12
            prefix-length: 32
          ip: 10.255.0.12
```

## Reading From the Local File

`nsci show` reads from `configs/<device>.json` — the local file, **not** the live device. If you've made edits that haven't been pushed yet, `show` reflects your edits.

To see what's actually on the device right now, use `nsci diff` or `nsci pull` to get a fresh copy.

## Tips

- **Don't know the section name?** Run `nsci show <device>` with no path to see all sections.
- **Section not found?** The error message shows available children at that level.
- **OpenConfig prefixes** (like `openconfig-system:system`) are stripped for readability. You can use just `system`, `interfaces`, etc.
- **For JSON-level edits**, you still need to open the raw file. `show` is read-only.
