# BGP Neighbor Service

Configures BGP peering sessions on a device.

## Supported platforms

- Arista EOS

## Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `bgp_as` | integer | yes | Local BGP AS number |
| `router_id` | string | yes | BGP router ID (usually Loopback0 IP) |
| `bgp_neighbors` | list | yes | List of BGP neighbor objects |
| `bgp_neighbors[].address` | string | yes | Neighbor IP address |
| `bgp_neighbors[].remote_as` | integer | yes | Neighbor AS number |
| `bgp_neighbors[].update_source` | string | yes | Source interface for BGP session |
| `bgp_neighbors[].description` | string | no | Neighbor description |

## Example

```yaml
bgp_as: 65000
router_id: 10.255.0.1
bgp_neighbors:
  - address: 10.255.0.2
    remote_as: 65000
    update_source: Loopback0
    description: RR1-NYC
  - address: 10.255.0.3
    remote_as: 65000
    update_source: Loopback0
    description: RR2-CHI
```
