# NTP Service

Configures NTP servers on a device.

## Supported platforms

- Arista EOS
- Cisco IOS / IOS-XE
- Cisco IOS-XR

## Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `ntp_servers` | list | yes | List of NTP server objects |
| `ntp_servers[].address` | string | yes | NTP server IP address |
| `ntp_servers[].prefer` | boolean | no | Mark as preferred server |

## Example

```yaml
ntp_servers:
  - address: 10.0.0.1
    prefer: true
  - address: 10.0.0.2
  - address: 10.0.0.3
```

## What it produces

```
ntp server 10.0.0.1 prefer
ntp server 10.0.0.2
ntp server 10.0.0.3
```
