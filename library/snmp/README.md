# SNMP Service

Configures SNMP monitoring parameters on a device.

## Supported platforms

- Arista EOS
- Cisco IOS / IOS-XE

## Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `snmp_contact` | string | yes | SNMP contact name |
| `snmp_location` | string | yes | Device physical location |
| `snmp_community` | string | yes | SNMP community string |
| `snmp_community_access` | string | yes | Access level: `ro` or `rw` |

## Example

```yaml
snmp_contact: netops-team
snmp_location: NYC-DC1-Row3-Rack12
snmp_community: my_community
snmp_community_access: ro
```
