# Supported Platforms

NetStacks CI supports devices that expose structured configuration APIs: gNMI, NETCONF, or REST. No SSH. No CLI.

## Platform Matrix

| Platform | Transport | Driver | Config Format | Status |
|---|---|---|---|---|
| **Arista EOS** (4.25+) | gNMI | `eos-gnmi` | OpenConfig JSON | Tested, production-ready |
| **Arista EOS** (legacy) | eAPI | `eos-eapi` | CLI-over-JSON | Tested, limited (no structural replace) |
| **Cisco IOS-XR** (7.5+) | NETCONF | `iosxr-netconf` | OpenConfig/native XML | Driver ready, needs testing |
| **Juniper Junos** (21.2+) | NETCONF | `junos-netconf` | OpenConfig/native XML | Driver planned |
| **Cisco NX-OS** (10.2+) | gNMI/NX-API | `nxos-gnmi` | OpenConfig JSON | Driver planned |
| **Nokia SR OS** | gNMI | `sros-gnmi` | OpenConfig JSON | Driver planned |
| **Palo Alto PAN-OS** | REST API | `paloalto-panorama` | Vendor JSON | Driver ready, needs testing |
| **F5 BIG-IP** | REST API | `f5-bigip` | Vendor JSON | Driver planned |
| **Cisco IOS/IOS-XE** (CLI-only) | — | — | — | Not supported (no structured API) |

## Why These Minimum Versions?

The minimum software versions ensure comprehensive OpenConfig/YANG model support. Older versions may have partial NETCONF/gNMI support but with gaps in config coverage that cause push failures.

| Platform | Why This Version |
|---|---|
| EOS 4.25+ | Full OpenConfig coverage, stable gNMI |
| IOS-XR 7.5+ | Native + OpenConfig YANG models for all standard features |
| Junos 21.2+ | Improved OpenConfig compliance |
| NX-OS 10.2+ | gNMI support, DME maturity |

## What "Supported" Means

A supported platform has:

1. **A driver** in `drivers/<driver-name>/driver.yaml` defining connection parameters
2. **Tested pull/push** — we've verified that `nsci pull` retrieves a valid JSON config and `nsci push` applies it correctly with the `replace` operation
3. **Correct reconciliation** — the device properly adds, removes, and modifies config based on the replace payload

## What About Devices Without gNMI/NETCONF?

Devices that only support CLI (SSH) are not supported by design. The core principle of NetStacks CI is that the device handles the "how" through structured APIs. CLI-based automation requires command generation, output parsing, and platform-specific logic — the exact complexity we're avoiding.

For CLI-only devices, consider:
- **Ansible** — mature CLI automation
- **Nornir** — Python framework for CLI tasks
- **Upgrading** — most vendors now support NETCONF/gNMI in current software releases

## Transport Details

### gNMI (gRPC Network Management Interface)

- **Protocol:** gRPC over HTTP/2
- **Port:** 6030 (Arista default), configurable
- **Encoding:** `json_ietf` (JSON with OpenConfig IETF encoding)
- **Operations:** `Get` (pull), `Set` with `Replace` (push)
- **Auth:** Username/password via gRPC metadata
- **TLS:** Recommended in production, optional in lab

### NETCONF (Network Configuration Protocol)

- **Protocol:** XML-RPC over SSH
- **Port:** 830 (standard)
- **Encoding:** XML with YANG namespace prefixes
- **Operations:** `get-config` (pull), `edit-config` with `operation="replace"` (push)
- **Auth:** SSH username/password or SSH keys
- **Datastores:** Running (direct) or Candidate + Commit

### REST API

- **Protocol:** HTTPS
- **Port:** 443 (standard)
- **Encoding:** JSON (vendor-specific schema)
- **Operations:** `GET` (pull), `PUT` (push/replace), `DELETE` (remove)
- **Auth:** API key, OAuth, or basic auth (defined in driver)

## Enabling APIs on Devices

### Arista EOS — gNMI and NETCONF

```
configure
management api gnmi
   transport grpc default
   no shutdown
management api netconf
   transport ssh default
   no shutdown
end
write memory
```

### Cisco IOS-XR — NETCONF

```
configure
netconf-yang agent ssh
commit
end
```

### Juniper Junos — NETCONF

```
set system services netconf ssh
commit
```
