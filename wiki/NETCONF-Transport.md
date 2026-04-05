# NETCONF Transport

NETCONF is an IETF standard protocol for device configuration management. It runs over SSH and uses XML with YANG-modeled data.

## What Is NETCONF?

NETCONF uses SSH as the transport and XML as the data format. It supports operations like `get-config`, `edit-config`, `commit`, and `validate`. YANG models define the structure of the config data.

```
nsci ──── SSH (port 830) ──── Device
          
Request:  edit-config with operation="replace"
Payload:  XML config
Response: <ok/> or <rpc-error>
```

## How nsci Uses NETCONF

### Pull (get-config)

```bash
nsci pull pe1-xr
```

Sends a NETCONF `get-config` request for `source=running`. The device returns its running config as XML. `nsci` converts it to JSON and saves as `configs/pe1-xr.json`.

### Push (edit-config with replace)

```bash
nsci push pe1-xr
```

Converts `configs/pe1-xr.json` back to XML and sends a NETCONF `edit-config` with `operation="replace"` on the relevant subtrees. The device reconciles.

### Section-Level Operations

NETCONF supports filtered operations — you can pull or push specific config subtrees:

```xml
<!-- Pull only NTP config -->
<get-config>
  <source><running/></source>
  <filter>
    <system xmlns="http://openconfig.net/yang/system">
      <ntp/>
    </system>
  </filter>
</get-config>

<!-- Replace only the NTP servers subtree -->
<edit-config>
  <target><running/></target>
  <config>
    <system xmlns="http://openconfig.net/yang/system">
      <ntp>
        <servers xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0" 
                 nc:operation="replace">
          <server>
            <address>10.0.0.1</address>
            <config><address>10.0.0.1</address></config>
          </server>
        </servers>
      </ntp>
    </system>
  </config>
</edit-config>
```

## Supported Devices

| Vendor | Platform | NETCONF Support | Default Port |
|---|---|---|---|
| Arista | EOS 4.20+ | OpenConfig | 830 |
| Cisco | IOS-XR 6.0+ | Native + OpenConfig | 830 |
| Cisco | IOS-XE 16.x+ | Native + OpenConfig (partial) | 830 |
| Juniper | Junos (all) | Native + OpenConfig | 830 |
| Nokia | SR OS | Native + OpenConfig | 830 |

## Enabling NETCONF

### Arista EOS

```
configure
management api netconf
   transport ssh default
   no shutdown
end
```

### Cisco IOS-XR

```
configure
netconf-yang agent ssh
commit
end
```

### Juniper Junos

```
set system services netconf ssh
commit
```

## The XML Format

NETCONF config uses YANG namespaces. Example NTP section:

```xml
<system xmlns="http://openconfig.net/yang/system">
  <ntp>
    <servers>
      <server>
        <address>10.0.0.1</address>
        <config>
          <address>10.0.0.1</address>
          <prefer>true</prefer>
        </config>
      </server>
    </servers>
  </ntp>
</system>
```

## NETCONF Operations Explained

| Operation | What It Does | nsci Usage |
|---|---|---|
| `get-config` | Pull config (filtered or full) | `nsci pull` |
| `edit-config` merge | Add/update, leave rest untouched | Adding new config |
| `edit-config` replace | Make subtree match payload exactly | `nsci push` (default) |
| `edit-config` delete | Remove a specific subtree | Removing config |
| `commit` | Apply candidate to running (XR/Junos) | After edit-config on candidate |
| `validate` | Check candidate for errors | Pre-push validation |

## Candidate vs Running Datastore

Some devices (IOS-XR, Junos) use a **candidate datastore**:

```
1. edit-config target=candidate    ← stage changes
2. validate                         ← check for errors
3. commit                           ← apply to running
```

Others (EOS) edit the running datastore directly:

```
1. edit-config target=running      ← changes applied immediately
```

The driver handles this difference. The engineer doesn't need to know.

## Proven Examples

### NTP Add/Remove via NETCONF

Tested against Arista EOS P3-AMS:
- Add NTP servers via `edit-config` merge → works
- Remove NTP server via `edit-config` replace (send only desired servers) → device removes the missing one
- Full NTP section replace → device reconciles perfectly

### Route-Map with Regex Community Lists

Tested against Arista EOS P3-AMS:
- Push OpenConfig `routing-policy` XML with community lists (including regex patterns like `65000:[1-9][0-9][0-9]`)
- Modify statements (remove statement 20, change local-pref on statement 10) via replace
- Device correctly added, modified, and removed route-map entries from a single replace operation

## Stack Delete (NETCONF)

When `nsci stack-delete` removes config via NETCONF, the mechanism depends on whether the template is OpenConfig or vendor-native.

### OpenConfig Templates — Automatic Injection

nsci injects `nc:operation="delete"` on known list item elements (`<server>`, `<neighbor>`, `<static>`, `<community-set>`, `<policy-definition>`, etc.). Only the specific list items are removed.

```xml
<!-- What nsci sends to remove an NTP server -->
<system xmlns="http://openconfig.net/yang/system">
  <ntp><servers>
    <server nc:operation="delete">
      <address>10.0.0.1</address>
    </server>
  </servers></ntp>
</system>
```

### Vendor-Native Templates — Operation Swap

For non-OpenConfig templates, nsci swaps all existing `nc:operation` attributes to `"delete"`:

- `nc:operation="replace"` → `nc:operation="delete"`
- `nc:operation="merge"` → `nc:operation="delete"`

Same deploy template handles both deploy and teardown. No separate delete template needed.

**Requirement:** Vendor-native templates must have explicit `nc:operation` on every operational element. Without them, nsci can't see what to swap and the render fails before anything touches a device.

```xml
<!-- Deploy: filter is replaced, binding is merged -->
<filter nc:operation="replace">
  <name>ACME-VOIP-FBF</name>
  ...
</filter>
<filter nc:operation="merge">
  <input><filter-name>ACME-VOIP-FBF</filter-name></input>
</filter>

<!-- Delete: nsci swaps both to delete -->
<filter nc:operation="delete">
  <name>ACME-VOIP-FBF</name>
  ...
</filter>
<filter nc:operation="delete">
  <input><filter-name>ACME-VOIP-FBF</filter-name></input>
</filter>
```

**The rule:** If nsci can't see it, nsci can't delete it. Implicit merge (no `nc:operation` attribute) is invisible to the swap.

---

## Troubleshooting

**Connection refused on port 830:**
- NETCONF not enabled on device
- SSH service not running
- Firewall blocking port 830

**"unexpected element" errors:**
- The YANG model you're referencing isn't supported on this device/version
- Check `show netconf-yang capabilities` (XR) or device capabilities

**Replace not working as expected:**
- Verify you're replacing the right subtree (not too broad, not too narrow)
- Some devices require candidate datastore + commit
