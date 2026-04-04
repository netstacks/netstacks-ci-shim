# Firewall Security Rule

Creates a security policy rule on Palo Alto (Panorama or NGFW).

## Supported platforms

- Palo Alto PAN-OS (via REST API)

## Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `rule_name` | string | yes | Name of the security rule |
| `src_zones` | list | yes | Source security zones |
| `dst_zones` | list | yes | Destination security zones |
| `src_addresses` | list | yes | Source addresses or groups |
| `dst_addresses` | list | yes | Destination addresses or groups |
| `applications` | list | yes | PAN-OS application signatures |
| `action` | string | yes | allow, deny, drop, reset-* |
| `log_profile` | string | no | Log forwarding profile name |

## Example

```yaml
rule_name: allow-cust-a-web
src_zones: [trust]
dst_zones: [untrust]
src_addresses: [10.100.0.0/16]
dst_addresses: [any]
applications: [web-browsing, ssl]
action: allow
log_profile: default
```

## How it works

The template produces JSON matching the PAN-OS REST API schema.
The shim pushes it via `PUT /restapi/v10.2/Policies/SecurityRules`.
Panorama handles rule compilation and push to managed firewalls.
