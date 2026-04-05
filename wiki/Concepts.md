# Concepts

NetStacks CI has four core concepts. Understanding these is all you need.

## Configs

**What:** One JSON file per device containing its full configuration.

**Where:** `configs/<device-name>.json`

**Example:** `configs/pe1-nyc.json` — the entire running config of PE1-NYC as structured JSON (OpenConfig format).

**How it works:**
- `nsci pull pe1-nyc` downloads the device's config into this file
- You edit the file to make changes
- `nsci push pe1-nyc` uploads the file back to the device
- The device reconciles — adds what's new, removes what's gone, updates what changed

**This is the source of truth.** Whatever is in this file is what the device should look like. If the device is different, it's either because you haven't pushed yet (pending change) or someone changed the device outside of `nsci` (drift).

```
configs/
  rr1-nyc.json           130KB   Route Reflector
  p1-nyc.json            132KB   P-Router NYC
  pe1-nyc.json           126KB   PE-Router NYC
  sw1-chi-techcorp.json  105KB   Customer Switch
```

## Stacks

**What:** A named group of devices that deploy together.

**Where:** `stacks/<stack-name>/stack.yaml`

**Why:** When a service spans multiple devices (like an L3VPN across PE and CE routers), you want all devices to succeed or all to roll back. A stack defines this relationship.

**Example:**

```yaml
# stacks/l3vpn-cust-a/stack.yaml
name: l3vpn-cust-a
description: L3VPN service for Customer A
atomic: true
devices:
  - pe1-nyc
  - pe2-nyc
  - ce1-nyc-globalbank
```

**`atomic: true`** — If any device fails, all devices in the stack get rolled back to their previous config. Either the entire L3VPN deploys or none of it does.

**`atomic: false`** — Each device is independent. Used for baseline configs (NTP, SNMP) where one device failing shouldn't block the others.

**How it works:**
```bash
nsci stack-deploy l3vpn-cust-a
```

This triggers a four-stage deploy:
1. Pre-flight: save current state of all devices
2. Push: send new configs to all devices in parallel
3. Validate: verify all devices match expected state
4. Rollback (if needed): restore all devices to pre-flight state

## Library

**What:** Reusable Jinja2 templates for common services like NTP, SNMP, BGP, firewall rules.

**Where:** `library/<service-name>/`

**Why:** Instead of editing raw JSON for common patterns, templates let you fill in simple YAML variables and generate the correct structured config.

**Who creates them:** The platform team builds templates. Engineers use them.

**Example:**

```
library/
  ntp/
    README.md            What this service does
    schema.yaml          Variable definitions (names, types, descriptions)
    template.xml.j2      Jinja2 template producing NETCONF XML
  fw-security-rule/
    README.md
    schema.yaml
    template.json.j2     Jinja2 template producing REST API JSON
```

**The schema** defines what variables the template needs:

```yaml
# library/ntp/schema.yaml
name: ntp
description: NTP server configuration
platforms: [eos, ios, iosxr]
variables:
  ntp_servers:
    type: list
    required: true
    description: NTP servers to configure
```

**The template** produces structured data from those variables:

```xml
<!-- library/ntp/template.xml.j2 -->
<config>
  <system xmlns="http://openconfig.net/yang/system">
    <ntp><servers>
      {%- for server in ntp_servers %}
      <server>
        <address>{{ server.address }}</address>
        <config><address>{{ server.address }}</address></config>
      </server>
      {%- endfor %}
    </servers></ntp>
  </system>
</config>
```

**Engineers never see the template.** They browse available services with `nsci library`, see what variables are needed, and fill them in. The template handles the rest.

**Library is optional.** You can manage your entire network by editing config files directly without ever using a template. The library is a convenience for standardized services.

## Drivers

**What:** Device communication adapters. Define how `nsci` talks to each device type.

**Where:** `drivers/<driver-name>/driver.yaml`

**Why:** Different devices speak different protocols. Arista uses gNMI, Cisco XR uses NETCONF, Palo Alto uses REST API. The driver tells `nsci` which protocol to use and how to connect.

**Who creates them:** Shipped with `nsci` or community-contributed. Engineers never write or modify drivers.

**Example:**

```yaml
# drivers/eos-gnmi/driver.yaml
name: eos-gnmi
transport: gnmi
platform: eos
gnmi:
  port: 6030
  encoding: json_ietf
  tls: true
capabilities:
  config_replace: true
  openconfig: true
```

**Drivers connect to devices via `inventory.yaml`:**

```yaml
# inventory.yaml
devices:
  pe1-nyc:
    hostname: 10.1.1.104
    driver: eos-gnmi        # ← uses drivers/eos-gnmi/driver.yaml
    credential: ...
```

**Available drivers:**

| Driver | Transport | Devices |
|---|---|---|
| `eos-gnmi` | gNMI (gRPC) | Arista EOS |
| `eos-eapi` | eAPI (HTTPS) | Arista EOS (legacy) |
| `iosxr-netconf` | NETCONF (SSH) | Cisco IOS-XR |
| `paloalto-panorama` | REST API (HTTPS) | Palo Alto Panorama |

## How They Fit Together

```
inventory.yaml          What devices exist, how to reach them
     │
     ├── configs/       What each device should look like (the data)
     │
     ├── stacks/        Which devices deploy together (the grouping)
     │
     ├── library/       Reusable templates for generating configs (optional)
     │
     └── drivers/       How to talk to each device type (the protocol)
```

**Simplest usage:** Inventory + configs. Pull a device, edit the JSON, push.

**Standard usage:** Add stacks for services that span multiple devices.

**Advanced usage:** Build templates in the library for repeatable services.
