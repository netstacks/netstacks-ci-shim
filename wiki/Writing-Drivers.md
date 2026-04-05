# Writing Drivers

A driver tells `nsci` how to communicate with a specific device type. Drivers are YAML files — no code required.

## When to Write a Driver

You need a new driver when:
- You have a device type not already covered (check `drivers/`)
- An existing device type uses a different port, encoding, or auth method than the default driver

You do **not** need a new driver for each individual device — only for each device *type*. All Arista EOS switches share the `eos-gnmi` driver.

## Driver Structure

```
drivers/<driver-name>/
  └── driver.yaml
```

One file. That's it.

## gNMI Driver

For devices that speak gNMI (Arista EOS, modern Cisco, Nokia):

```yaml
# drivers/eos-gnmi/driver.yaml
name: eos-gnmi
transport: gnmi
platform: eos

gnmi:
  port: 6030                    # gNMI port
  encoding: json_ietf           # json or json_ietf
  tls: true                     # Use TLS (recommended for production)

capabilities:
  config_replace: true          # Supports full config replace
  openconfig: true              # Uses OpenConfig models
```

### Fields

| Field | Required | Description |
|---|---|---|
| `name` | yes | Driver identifier (referenced in inventory) |
| `transport` | yes | `gnmi`, `netconf`, `eapi`, or `rest_api` |
| `platform` | yes | Platform identifier for model selection |
| `gnmi.port` | no | gNMI port (default: 6030) |
| `gnmi.encoding` | no | `json_ietf` (default) or `json` |
| `gnmi.tls` | no | Enable TLS (default: true) |
| `capabilities.config_replace` | no | Device supports replace operations |
| `capabilities.openconfig` | no | Device supports OpenConfig models |

## NETCONF Driver

For devices that speak NETCONF (Cisco IOS-XR, Juniper Junos, Arista EOS):

```yaml
# drivers/iosxr-netconf/driver.yaml
name: iosxr-netconf
transport: netconf
platform: iosxr

netconf:
  port: 830                     # NETCONF port
  hostkey_verify: false          # Verify SSH host keys

capabilities:
  config_replace: true
  candidate_datastore: true      # Uses candidate datastore (requires commit)
  commit_confirm: true           # Supports commit confirmed (with timer)
  rollback_on_error: true        # Automatic rollback on error

yang_models:
  native: Cisco-IOS-XR           # Vendor-native YANG model prefix
  openconfig: true               # Also supports OpenConfig models
```

### NETCONF-Specific Fields

| Field | Description |
|---|---|
| `netconf.port` | SSH port for NETCONF (default: 830) |
| `netconf.hostkey_verify` | Verify SSH host key (disable for lab) |
| `capabilities.candidate_datastore` | Device uses candidate + commit model |
| `capabilities.commit_confirm` | Supports `commit confirmed <timeout>` |
| `yang_models.native` | Vendor-specific YANG model namespace prefix |
| `yang_models.openconfig` | Device supports OpenConfig models |

## REST API Driver

For devices with HTTP-based management APIs (Palo Alto, F5, cloud):

```yaml
# drivers/paloalto-panorama/driver.yaml
name: paloalto-panorama
transport: rest_api
platform: paloalto

rest_api:
  base_path: /restapi/v10.2
  auth:
    type: api_key               # api_key, basic, oauth2, or session
    header: X-PAN-KEY           # Header name for the API key

resources:
  security_rule:
    create: POST /restapi/v10.2/Policies/SecurityRules
    read:   GET  /restapi/v10.2/Policies/SecurityRules?name={name}
    update: PUT  /restapi/v10.2/Policies/SecurityRules?name={name}
    delete: DELETE /restapi/v10.2/Policies/SecurityRules?name={name}
    id_field: name              # Field that uniquely identifies a resource

  commit:
    action: POST /restapi/v10.2/Operations/Commit

  dependencies:
    security_rule: [address_object]   # Create order
```

### REST API-Specific Fields

| Field | Description |
|---|---|
| `rest_api.base_path` | API URL prefix |
| `rest_api.auth.type` | Authentication method |
| `rest_api.auth.header` | Header name for API key auth |
| `resources.<name>` | Resource type with CRUD endpoints |
| `resources.<name>.id_field` | Field used to identify resources |
| `resources.dependencies` | Resource creation order |
| `resources.commit.action` | Commit endpoint (if device stages changes) |

## eAPI Driver (Arista Legacy)

For Arista EOS devices using eAPI instead of gNMI:

```yaml
# drivers/eos-eapi/driver.yaml
name: eos-eapi
transport: eapi
platform: eos

eapi:
  port: 443
  protocol: https
  verify_ssl: false

capabilities:
  config_sessions: true         # Supports configure sessions
  session_diff: true            # Can show session diffs
  json_output: true             # show commands return JSON
  config_replace: true          # Supports configure replace
```

## Connecting Drivers to Devices

In `inventory.yaml`, the `driver` field references the driver name:

```yaml
devices:
  pe1-nyc:
    hostname: 10.1.1.104
    driver: eos-gnmi              # → uses drivers/eos-gnmi/driver.yaml
    credential:
      username: admin
      password: admin123

  fw-panorama:
    hostname: 10.1.1.200
    driver: paloalto-panorama     # → uses drivers/paloalto-panorama/driver.yaml
    credential:
      username: admin
      api_key: LUFRPT1234...
```

## Testing a New Driver

1. Add the driver YAML to `drivers/<name>/driver.yaml`
2. Add a test device to `inventory.yaml` referencing the driver
3. Test connectivity: `nsci pull <device>`
4. Test push: make a small change, `nsci push <device>`
5. Validate: `nsci validate <device>`

## Contributing Drivers

Community drivers are welcome. To contribute:

1. Create the driver YAML
2. Test against a real device
3. Document which platform versions are supported
4. Submit a PR to the netstacks-ci repo
