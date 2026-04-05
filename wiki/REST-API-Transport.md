# REST API Transport

REST APIs are used for devices that don't speak gNMI or NETCONF — firewalls, load balancers, SD-WAN controllers, cloud networking, and other infrastructure with HTTP-based management interfaces.

## What Devices Use REST APIs?

| Device | API | Data Format |
|---|---|---|
| Palo Alto Panorama/NGFW | PAN-OS REST API | JSON |
| F5 BIG-IP | iControl REST | JSON |
| Fortinet FortiManager | FortiManager API | JSON |
| Checkpoint | Management API | JSON |
| A10 Thunder | aXAPI | JSON |
| Cisco ACI | APIC REST API | JSON/XML |
| Cisco Catalyst Center | DNA Center API | JSON |
| AWS VPC/TGW | AWS EC2 API | JSON |
| Azure Virtual Network | ARM REST API | JSON |

## How REST APIs Differ from gNMI/NETCONF

| | gNMI/NETCONF | REST API |
|---|---|---|
| **Standard** | Industry standard, same across vendors | Vendor-specific endpoints and schema |
| **Full config** | Pull/push entire device config | Operate on individual resources |
| **Replace** | Replace entire config tree | PUT/POST individual resources |
| **Data model** | OpenConfig (vendor-neutral) | Vendor-specific JSON schema |

The key difference: gNMI/NETCONF devices accept a full config replace. REST API devices typically operate on individual **resources** — a firewall rule, a load balancer pool, a VPN tunnel.

## How nsci Handles REST APIs

### Drivers Define Endpoints

The driver for a REST API device maps operations to HTTP endpoints:

```yaml
# drivers/paloalto-panorama/driver.yaml
name: paloalto-panorama
transport: rest_api

rest_api:
  base_path: /restapi/v10.2
  auth:
    type: api_key
    header: X-PAN-KEY

resources:
  security_rule:
    create: POST /restapi/v10.2/Policies/SecurityRules
    read:   GET  /restapi/v10.2/Policies/SecurityRules?name={name}
    update: PUT  /restapi/v10.2/Policies/SecurityRules?name={name}
    delete: DELETE /restapi/v10.2/Policies/SecurityRules?name={name}
    id_field: name

  address_object:
    create: POST /restapi/v10.2/Objects/Addresses
    read:   GET  /restapi/v10.2/Objects/Addresses?name={name}
    update: PUT  /restapi/v10.2/Objects/Addresses?name={name}
    delete: DELETE /restapi/v10.2/Objects/Addresses?name={name}
    id_field: name

  commit:
    action: POST /restapi/v10.2/Operations/Commit

  dependencies:
    security_rule: [address_object]
```

### Templates Produce JSON Payloads

Library templates for REST API devices produce the JSON body that the API expects:

```json
{# library/fw-security-rule/template.json.j2 #}
{
  "entry": {
    "@name": "{{ rule_name }}",
    "from": { "member": {{ src_zones | tojson }} },
    "to": { "member": {{ dst_zones | tojson }} },
    "source": { "member": {{ src_addresses | tojson }} },
    "destination": { "member": {{ dst_addresses | tojson }} },
    "application": { "member": {{ applications | tojson }} },
    "action": "{{ action }}"
  }
}
```

### Operations

| Operation | HTTP Method | What Happens |
|---|---|---|
| **Create** | POST | Creates a new resource |
| **Read** | GET | Retrieves current resource state |
| **Update** | PUT | Replaces the resource (like gNMI replace, but per-resource) |
| **Delete** | DELETE | Removes the resource |
| **Commit** | POST (action) | Commits staged changes (Palo Alto, Checkpoint) |

### Dependencies

Some resources depend on others. The driver defines this:

```yaml
dependencies:
  security_rule: [address_object]   # Create address objects before rules
```

On deploy: address objects are created first, then security rules.
On delete: security rules are deleted first, then address objects (reverse order).

## Authentication

REST APIs use various auth methods. The driver defines which one:

| Auth Type | Driver Config | How It Works |
|---|---|---|
| API Key | `type: api_key, header: X-PAN-KEY` | Key sent in HTTP header |
| Basic Auth | `type: basic` | Username:password base64 encoded |
| OAuth2 | `type: oauth2, token_url: /api/token` | Client credentials flow |
| Session Token | `type: session, login_url: /api/login` | Login first, use session cookie |

Credentials are resolved from `inventory.yaml` (inline or vault reference).

## Config Files for REST API Devices

REST API devices don't have a single "full config" like gNMI devices. Instead, the config file contains the resources managed by `nsci`:

```json
{
  "security_rules": [
    {
      "name": "allow-web",
      "from": {"member": ["trust"]},
      "to": {"member": ["untrust"]},
      "action": "allow"
    }
  ],
  "address_objects": [
    {
      "name": "web-servers",
      "ip-netmask": "10.0.0.0/24"
    }
  ]
}
```

This is a different model from the full-device-config approach used for gNMI/NETCONF devices. REST API device management is resource-oriented, not config-replace-oriented.

## Current Status

| Driver | State | Notes |
|---|---|---|
| `paloalto-panorama` | Driver written, not tested against real device | Endpoint definitions based on PAN-OS 10.2 API docs |
| `f5-bigip` | Planned | iControl REST well-documented |
| `fortinet` | Planned | FortiManager API |
| `aws-vpc` | Planned | AWS EC2/VPC APIs |

REST API support is newer than gNMI/NETCONF. Contributions welcome.
