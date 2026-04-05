# Service Templates

The library contains reusable templates for common network services. Instead of editing raw JSON for standard configs like NTP, SNMP, or BGP, templates let you fill in simple variables and generate the correct structured output.

## How Templates Work

```
library/ntp/
  ├── README.md           What this service does
  ├── schema.yaml         Variable definitions
  └── template.xml.j2     Jinja2 template → NETCONF XML output
```

1. The **schema** defines what variables the template needs (names, types, descriptions)
2. The **template** is a Jinja2 file that produces structured data (XML for NETCONF, JSON for REST APIs)
3. The **README** documents the service for engineers

## Browsing the Library

```bash
# List all available templates
nsci library
```

```
Service                   Platforms                 Description
--------------------------------------------------------------------------------
bgp-neighbor              eos                       BGP peering configuration
fw-security-rule          paloalto                  Palo Alto firewall security policy rule
ntp                       eos, ios, iosxr           NTP server configuration
snmp                      eos, ios                  SNMP monitoring configuration
```

```bash
# Details for a specific service
nsci library ntp
```

```
Service: ntp
Description: NTP server configuration
Platforms: eos, ios, iosxr

  ntp_servers (list, required): NTP servers to configure
```

## Available Templates

### NTP

Configures NTP servers on a device.

**Platforms:** Arista EOS, Cisco IOS, Cisco IOS-XR

**Variables:**
```yaml
ntp_servers:
  - address: 10.0.0.1
    prefer: true
  - address: 10.0.0.2
```

**Produces (NETCONF XML):**
```xml
<config>
  <system xmlns="http://openconfig.net/yang/system">
    <ntp><servers>
      <server>
        <address>10.0.0.1</address>
        <config>
          <address>10.0.0.1</address>
          <prefer>true</prefer>
        </config>
      </server>
      <server>
        <address>10.0.0.2</address>
        <config><address>10.0.0.2</address></config>
      </server>
    </servers></ntp>
  </system>
</config>
```

### SNMP

Configures SNMP monitoring parameters.

**Platforms:** Arista EOS, Cisco IOS

**Variables:**
```yaml
snmp_contact: netops-team
snmp_location: NYC-DC1-Row3
snmp_community: my_community
snmp_community_access: ro
```

### BGP Neighbor

Configures BGP peering sessions.

**Platforms:** Arista EOS

**Variables:**
```yaml
bgp_as: 65000
router_id: 10.255.0.1
bgp_neighbors:
  - address: 10.255.0.2
    remote_as: 65000
    update_source: Loopback0
    description: RR1-NYC
```

### BGP Import Policy

Configures route-maps with community list matching (including regex).

**Platforms:** Arista EOS (via NETCONF OpenConfig)

**Variables:**
```yaml
policy_name: CUST-A-IMPORT
community_lists:
  - name: CUST-A-COMMS
    members: ["65000:100", "65000:200"]
  - name: CUST-REGEX
    members: ["65000:[1-9][0-9][0-9]"]
statements:
  - sequence: 10
    action: permit
    match_community: CUST-A-COMMS
    set_local_pref: 200
  - sequence: 999
    action: deny
```

### Firewall Security Rule

Creates security policy rules on Palo Alto Panorama.

**Platforms:** Palo Alto PAN-OS (REST API)

**Variables:**
```yaml
rule_name: allow-web-traffic
src_zones: [trust]
dst_zones: [untrust]
src_addresses: [10.0.0.0/8]
dst_addresses: [any]
applications: [web-browsing, ssl]
action: allow
log_profile: default
```

**Produces (REST API JSON):**
```json
{
  "entry": {
    "@name": "allow-web-traffic",
    "from": {"member": ["trust"]},
    "to": {"member": ["untrust"]},
    "source": {"member": ["10.0.0.0/8"]},
    "destination": {"member": ["any"]},
    "application": {"member": ["web-browsing", "ssl"]},
    "action": "allow"
  }
}
```

## Templates vs Direct Config Editing

| | Templates | Direct Editing |
|---|---|---|
| **Best for** | Standardized, repeatable services | One-off changes, device-specific tuning |
| **Input** | YAML variables | JSON config file |
| **Output** | Structured XML/JSON | Same JSON file (modified) |
| **Knowledge needed** | Service parameters | OpenConfig JSON structure |
| **When to use** | "Deploy NTP on 50 devices" | "Change this one BGP timer on PE1" |

You can use both approaches in the same repo. Templates generate config that gets merged into device JSON files. Direct edits modify the files by hand.

## See Also

- [[Writing Templates]] — How to create new templates
- [[Template Schemas]] — Variable definitions for UI integration
