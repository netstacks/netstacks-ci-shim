# Template Schemas

Every template in the library has a `schema.yaml` that defines its variables. Schemas serve two purposes:

1. **Documentation** — `nsci library <name>` reads the schema to show what variables are needed
2. **UI Integration** — The NetStacks product reads schemas to generate input forms automatically

## Schema Format

```yaml
name: ntp                           # Service identifier
description: NTP server config      # Human-readable description
platforms: [eos, ios, iosxr]        # Which platforms this template supports

variables:
  variable_name:
    type: string                    # Data type
    required: true                  # Required or optional
    description: What this is       # Shown in UI and CLI
    default: some_value             # Default if not provided
    example: "10.0.0.1"            # Example value for documentation
    choices: [a, b, c]             # Valid options (for dropdowns in UI)
    sensitive: false                # If true, UI renders as password field
```

## Variable Types

| Type | JSON Equivalent | Example |
|---|---|---|
| `string` | `"value"` | IP addresses, names, descriptions |
| `integer` | `42` | AS numbers, ports, VLAN IDs |
| `boolean` | `true`/`false` | Enable/disable flags |
| `list` | `[...]` | Multiple servers, neighbors, rules |

### List Variables

Lists have an `items` field that defines the structure of each list entry:

```yaml
variables:
  ntp_servers:
    type: list
    required: true
    description: NTP servers to configure
    items:
      address:
        type: string
        required: true
        description: NTP server IP address
        example: "10.0.0.1"
      prefer:
        type: boolean
        required: false
        default: false
        description: Mark as preferred server
```

The corresponding YAML that an engineer fills in:

```yaml
ntp_servers:
  - address: 10.0.0.1
    prefer: true
  - address: 10.0.0.2
```

### Constrained Variables

Use `choices` to restrict values:

```yaml
  action:
    type: string
    required: true
    choices: [allow, deny, drop, reset-client, reset-server, reset-both]
    description: Firewall rule action
```

The CLI shows this as documentation. The NetStacks UI renders it as a dropdown.

### Sensitive Variables

Mark credentials and secrets:

```yaml
  snmp_community:
    type: string
    required: true
    sensitive: true
    description: SNMP community string
```

The NetStacks UI renders this as a password field. The CLI doesn't print the value when displaying the schema.

## Full Example

```yaml
# library/bgp-neighbor/schema.yaml
name: bgp-neighbor
description: BGP peering configuration
platforms: [eos]

variables:
  bgp_as:
    type: integer
    required: true
    description: Local BGP AS number
    example: 65000

  router_id:
    type: string
    required: true
    description: BGP router ID (usually Loopback0 IP)
    example: "10.255.0.1"

  bgp_neighbors:
    type: list
    required: true
    description: BGP neighbor sessions
    items:
      address:
        type: string
        required: true
        description: Neighbor IP address
        example: "10.255.0.2"
      remote_as:
        type: integer
        required: true
        description: Neighbor AS number
        example: 65000
      update_source:
        type: string
        required: true
        description: Source interface
        example: "Loopback0"
      description:
        type: string
        required: false
        description: Neighbor description
        example: "RR1-NYC"
```

## How NetStacks Uses Schemas

When the NetStacks product reads this schema, it generates a form:

```
┌──────────────────────────────────────┐
│  Deploy: BGP Neighbor                │
│                                      │
│  BGP AS:        [65000          ]    │
│  Router ID:     [10.255.0.1     ]    │
│                                      │
│  Neighbors:                          │
│  ┌────────────────────────────────┐  │
│  │ Address:    [10.255.0.2     ]  │  │
│  │ Remote AS:  [65000          ]  │  │
│  │ Source:     [Loopback0      ]  │  │
│  │ Description:[RR1-NYC        ]  │  │
│  └────────────────────────────────┘  │
│  [+ Add Neighbor]                    │
│                                      │
│  [Preview]  [Deploy]                 │
└──────────────────────────────────────┘
```

The schema drives the entire form — field names, types, validation, defaults, and help text. No custom UI code per template.
