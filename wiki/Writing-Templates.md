# Writing Templates

This guide covers creating new service templates for the library. You only need to do this when adding a new service type that doesn't exist yet.

## Template Structure

Each template lives in its own directory under `library/`:

```
library/my-new-service/
  ├── README.md           Documentation (required)
  ├── schema.yaml         Variable definitions (required)
  └── template.xml.j2     The Jinja2 template (required — .xml.j2 or .json.j2)
```

## Step-by-Step: Creating a Syslog Template

### 1. Understand the Target Config

First, see what the config looks like on a real device. Pull a device that has syslog configured and browse it:

```bash
nsci show pe1-nyc system/logging
```

Or pull the full config via gNMI and look at the raw JSON to understand the OpenConfig structure:

```bash
nsci pull pe1-nyc
python3 -c "
import json
config = json.load(open('configs/pe1-nyc.json'))
logging = config.get('openconfig-system:system', {}).get('logging', {})
print(json.dumps(logging, indent=2))
"
```

### 2. Create the Directory

```bash
mkdir -p library/syslog
```

### 3. Write the Template

The template is Jinja2 that produces the structured data format your target protocol expects.

**For NETCONF devices (XML):**

```xml
<!-- library/syslog/template.xml.j2 -->
<config>
  <system xmlns="http://openconfig.net/yang/system">
    <logging>
      <remote-servers>
        {%- for server in syslog_servers %}
        <remote-server>
          <host>{{ server.host }}</host>
          <config>
            <host>{{ server.host }}</host>
            <remote-port>{{ server.port | default(514) }}</remote-port>
            {%- if server.get('facility') %}
            <openconfig-system-ext:facility>{{ server.facility }}</openconfig-system-ext:facility>
            {%- endif %}
          </config>
        </remote-server>
        {%- endfor %}
      </remote-servers>
    </logging>
  </system>
</config>
```

**For REST API devices (JSON):**

```json
{# library/syslog-paloalto/template.json.j2 #}
{
  "entry": {
    "@name": "{{ profile_name }}",
    "server": {
      "entry": [
        {%- for server in syslog_servers %}
        {
          "@name": "{{ server.host }}",
          "transport": "{{ server.transport | default('UDP') }}",
          "port": "{{ server.port | default(514) }}",
          "facility": "{{ server.facility | default('LOG_USER') }}"
        }{{ "," if not loop.last }}
        {%- endfor %}
      ]
    }
  }
}
```

### 4. Write the Schema

The schema defines the variables the template needs. This is used by `nsci library` for documentation and by the NetStacks UI to generate input forms.

```yaml
# library/syslog/schema.yaml
name: syslog
description: Syslog remote server configuration
platforms: [eos, iosxr, junos]

variables:
  syslog_servers:
    type: list
    required: true
    description: Remote syslog servers
    items:
      host:
        type: string
        required: true
        description: Syslog server IP or hostname
        example: "10.0.0.50"
      port:
        type: integer
        required: false
        default: 514
        description: Syslog port
      facility:
        type: string
        required: false
        description: Syslog facility
        choices: [kern, user, mail, daemon, auth, syslog, local0, local1, local2, local3, local4, local5, local6, local7]
        default: local0
```

### 5. Write the README

```markdown
# Syslog Service

Configures remote syslog servers on a device.

## Supported Platforms
- Arista EOS
- Cisco IOS-XR
- Juniper Junos

## Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `syslog_servers` | list | yes | Remote syslog servers |
| `syslog_servers[].host` | string | yes | Server IP or hostname |
| `syslog_servers[].port` | integer | no | Port (default: 514) |
| `syslog_servers[].facility` | string | no | Facility (default: local0) |

## Example

\```yaml
syslog_servers:
  - host: 10.0.0.50
    facility: local0
  - host: 10.0.0.51
    port: 1514
    facility: local7
\```
```

### 6. Verify

```bash
nsci library syslog
```

Should show your new template with its variables.

## Jinja2 Tips

### Whitespace Control

Use `{%-` and `-%}` to strip whitespace around tags:

```
{%- for server in servers %}      ← no blank line before
{{ server.host }}
{%- endfor %}                     ← no blank line after
```

### Default Values

```
{{ server.port | default(514) }}
```

### Conditional Sections

```
{%- if server.get('facility') %}
<facility>{{ server.facility }}</facility>
{%- endif %}
```

### Loop Helpers

```
{%- for item in items %}
{{ item }}{{ "," if not loop.last }}
{%- endfor %}
```

### JSON Output

Use `| tojson` for lists and complex values:

```
"members": {{ members | tojson }}
```

Produces `"members": ["a", "b", "c"]` from a Python list.

## Template Format by Transport

| Device Transport | Template Extension | Output Format |
|---|---|---|
| NETCONF | `template.xml.j2` | XML with YANG namespaces |
| gNMI | `template.json.j2` | OpenConfig JSON |
| REST API | `template.json.j2` | Vendor-specific JSON |

## Testing Your Template

Render it manually to verify the output:

```bash
python3 -c "
import jinja2, yaml
env = jinja2.Environment(loader=jinja2.FileSystemLoader('library/syslog'))
template = env.get_template('template.xml.j2')
variables = yaml.safe_load(open('test-variables.yaml'))
print(template.render(**variables))
"
```
