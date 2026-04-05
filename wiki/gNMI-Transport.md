# gNMI Transport

gNMI (gRPC Network Management Interface) is the primary transport for NetStacks CI. It's a modern, high-performance protocol for pushing and pulling structured device configs.

## What Is gNMI?

gNMI is a Google-designed protocol for network device management. It runs over gRPC (HTTP/2) and uses OpenConfig YANG models to define the config structure. The data format is JSON.

```
nsci ──── gRPC (HTTP/2) ──── Device
          port 6030
          
Request:  Set Replace / with JSON payload
Response: OK or error
```

## How nsci Uses gNMI

### Pull (gNMI Get)

```bash
nsci pull pe1-nyc
```

Sends a gNMI `Get` request for path `/` with `datatype=config`. The device returns its entire running config as a JSON object. This is saved as `configs/pe1-nyc.json`.

### Push (gNMI Set Replace)

```bash
nsci push pe1-nyc
```

Sends a gNMI `Set` request with `replace` operation on path `/`. The payload is the entire `configs/pe1-nyc.json`. The device replaces its running config to match.

### What "Replace" Means

The device compares the payload to its current running config and:
- **Adds** anything in the payload not on the device
- **Removes** anything on the device not in the payload
- **Modifies** anything that differs
- **Ignores** anything that matches

This is a single atomic operation. The device does all the work internally.

## Supported Devices

| Vendor | Platform | gNMI Support | Default Port |
|---|---|---|---|
| Arista | EOS 4.25+ | Full OpenConfig | 6030 |
| Cisco | IOS-XR 7.5+ | OpenConfig + native | 57400 |
| Cisco | NX-OS 10.2+ | OpenConfig (partial) | 50051 |
| Nokia | SR OS | Full OpenConfig | 57400 |
| Juniper | Junos 21.2+ | OpenConfig | 32767 |

## Enabling gNMI on Arista EOS

```
configure
management api gnmi
   transport grpc default
   no shutdown
end
write memory
```

Verify:
```
show management api gnmi
```

Should show: `Enabled: yes`, `Server: running on port 6030`

## The JSON Format

gNMI with `json_ietf` encoding produces OpenConfig JSON. Example NTP section:

```json
{
  "openconfig-system:server": [
    {
      "address": "10.0.0.1",
      "config": {
        "address": "10.0.0.1"
      }
    },
    {
      "address": "10.0.0.2",
      "config": {
        "address": "10.0.0.2",
        "prefer": true
      }
    }
  ]
}
```

This is the same format whether you're talking to Arista, Cisco, Juniper, or Nokia. OpenConfig is vendor-neutral.

Vendor-specific extensions appear as prefixed keys:

```json
"arista-rpol-augments:policy-type": "ROUTE_MAP"
```

## Connection Details

The driver defines gNMI connection parameters:

```yaml
# drivers/eos-gnmi/driver.yaml
name: eos-gnmi
transport: gnmi
gnmi:
  port: 6030
  encoding: json_ietf
  tls: true
capabilities:
  config_replace: true
  openconfig: true
```

In `inventory.yaml`, the device references the driver:

```yaml
devices:
  pe1-nyc:
    hostname: 10.1.1.104
    driver: eos-gnmi
    credential:
      username: admin
      password: admin123
```

## TLS Configuration

**Production:** Enable TLS on the device and configure certificates:

```
management api gnmi
   transport grpc default
   ssl profile MY-PROFILE
```

**Lab/testing:** gNMI works without TLS when the device has no SSL profile configured. `nsci` connects with `insecure=True`.

## Performance

gNMI is fast:
- **Pull:** Full device config in 1-3 seconds
- **Push:** Config replace in 2-5 seconds
- **Protocol overhead:** Minimal (gRPC binary framing, HTTP/2 multiplexing)

For 10 parallel pushes with `nsci deploy`, total time is typically 5-10 seconds (limited by the slowest device, not the protocol).

## Origin Prefix Stripping

Some devices (notably Arista EOS) reject gNMI `Set` requests that include YANG module origin prefixes in the path. For example, `/openconfig-system:system/ntp` gets rejected — the device wants `/system/ntp`.

nsci automatically strips origin prefixes from all gNMI paths before sending them to devices. The first path element's module prefix (e.g., `openconfig-system:`) is removed. This is transparent — you never need to worry about it in templates or schema paths.

## Stack Delete (gNMI)

When `nsci stack-delete` removes config via gNMI:

### OpenConfig Services — Per-Item Precision

nsci walks the rendered JSON and builds individual `Set delete` paths for each list item:

```
DELETE /network-instances/network-instance[name=default]/protocols/protocol[identifier=BGP][name=BGP]/bgp/neighbors/neighbor[neighbor-address=10.255.0.2]
DELETE /system/ntp/servers/server[address=10.0.0.1]
DELETE /routing-policy/defined-sets/bgp-defined-sets/community-sets/community-set[community-set-name=CUST-A-COMMS]
```

Only the specific list items are removed. Pre-existing config on the device is untouched.

### Vendor-Specific Services — Base Path Delete (Known Gap)

For non-OpenConfig services deployed via gNMI, nsci cannot build per-item delete paths because it doesn't know the vendor-specific YANG list key structure. It falls back to deleting the **entire schema base path**.

This means: if the schema path is `/junos-conf:configuration/firewall`, a `stack-delete` removes everything under `/configuration/firewall` — not just the filter the stack created.

**This is a known architectural gap.** Vendor-specific services that need surgical delete precision should use NETCONF transport, where the `nc:operation` swap mechanism provides per-element control.

---

## Troubleshooting

**Connection timeout:**
- Verify gNMI is enabled: `show management api gnmi` on the device
- Verify port connectivity: `nc -zv <ip> 6030`
- Check firewall rules between the runner/workstation and the device

**Authentication failure:**
- Verify credentials in `inventory.yaml`
- Some devices require specific AAA configuration for gNMI access

**Replace rejected:**
- The JSON may contain values the device doesn't accept
- Check the device logs for specific error messages
- Try pulling a fresh config first (`nsci pull`) to ensure the JSON structure matches what the device expects
