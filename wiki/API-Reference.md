# API Reference

nsci can run as a REST API server, exposing all CLI operations as HTTP endpoints. This is used by the NetStacks platform and can be used directly for automation.

## Starting the Server

```bash
# Default: 0.0.0.0:8080
nsci serve

# Custom host/port
nsci serve --host 127.0.0.1 --port 9090

# Debug mode (auto-reload on code changes)
nsci serve --debug
```

Requires Flask: `pip install flask` (included in `requirements.txt`).

## OpenAPI Spec

The full OpenAPI 3.0 spec is available at:

```
GET /api/v1/openapi.json
```

You can point Swagger UI, Postman, or any OpenAPI tool at this URL to browse and test the API interactively.

---

## Authentication

Set `NSCI_API_TOKEN` to require bearer token auth on all requests:

```bash
NSCI_API_TOKEN=mysecrettoken nsci serve
```

All requests must include the header:

```
Authorization: Bearer mysecrettoken
```

If `NSCI_API_TOKEN` is not set, the API runs without authentication (lab/dev use).

## Response Format

All endpoints return JSON:

```json
{
  "ok": true,
  "exit_code": 0,
  "output": "Device               Hostname           Driver...\n..."
}
```

| Field | Type | Description |
|---|---|---|
| `ok` | boolean | `true` if the operation succeeded |
| `exit_code` | integer | 0 = success, 1 = failure |
| `output` | string | Text output (same as CLI) |

## Endpoints

### Health

```
GET /api/v1/health
```

Returns server status. No auth required if auth is disabled.

```json
{"ok": true, "mode": "api", "version": "nsci"}
```

---

### Device Operations

#### List all devices

```
GET /api/v1/status
```

Same as `nsci status`.

#### Show device config

```
GET /api/v1/devices/{device}
GET /api/v1/devices/{device}?section=system/ntp
```

Same as `nsci show <device> [section]`.

#### Pull device config

```
POST /api/v1/devices/{device}/pull
```

Same as `nsci pull <device>`. Pulls running config from device into `configs/`.

#### Push config to device

```
POST /api/v1/devices/{device}/push
Content-Type: application/json

{"full_replace": true}
```

Same as `nsci push <device> --full-replace`. The `full_replace` field is required.

#### Diff file vs device

```
GET /api/v1/devices/{device}/diff
```

Same as `nsci diff <device>`.

#### Validate device matches file

```
GET /api/v1/devices/{device}/validate
```

Same as `nsci validate <device>`.

#### View change history

```
GET /api/v1/devices/{device}/history
GET /api/v1/devices/{device}/history?count=20
GET /api/v1/devices/{device}/history?diff=0
```

Same as `nsci history <device> [--count N] [--diff N]`.

#### Rollback to previous version

```
POST /api/v1/devices/{device}/rollback
Content-Type: application/json

{"version": 1}
```

Same as `nsci rollback <device> <version>`. Pushes to device by default.

Optional: `{"version": 1, "no_push": true}` to only restore the file.

---

### Stack Operations

#### List stacks

```
GET /api/v1/stacks
```

Same as `nsci stack-list`.

#### Render stack (dry run)

```
GET /api/v1/stacks/{stack}/render
GET /api/v1/stacks/{stack}/render?delete=true
```

Same as `nsci stack-render <stack> [--delete]`.

#### Deploy stack

```
POST /api/v1/stacks/{stack}/deploy
```

Same as `nsci stack-deploy <stack>`. This is a long-running operation — the request blocks until complete.

#### Delete stack

```
POST /api/v1/stacks/{stack}/delete
```

Same as `nsci stack-delete <stack>`.

---

### Library

#### List all templates

```
GET /api/v1/library
```

Same as `nsci library`.

#### Template details

```
GET /api/v1/library/{service}
```

Same as `nsci library <service>`.

---

## Examples

### curl

```bash
# Pull a device config
curl -X POST http://localhost:8080/api/v1/devices/pe1-nyc/pull

# Show NTP config
curl "http://localhost:8080/api/v1/devices/pe1-nyc?section=system/ntp"

# Deploy a stack
curl -X POST http://localhost:8080/api/v1/stacks/baseline-ntp/deploy

# With authentication
curl -H "Authorization: Bearer mytoken" http://localhost:8080/api/v1/status
```

### Python

```python
import requests

API = "http://localhost:8080/api/v1"
HEADERS = {"Authorization": "Bearer mytoken"}

# Pull config
r = requests.post(f"{API}/devices/pe1-nyc/pull", headers=HEADERS)
print(r.json()["output"])

# Deploy stack
r = requests.post(f"{API}/stacks/l3vpn-cust-a/deploy", headers=HEADERS)
if r.json()["ok"]:
    print("Deploy succeeded")
else:
    print(f"Deploy failed:\n{r.json()['output']}")
```

## Production Deployment

The built-in Flask server is for development and small-scale use. For production, use a WSGI server:

```bash
# With gunicorn (multiple workers)
pip install gunicorn
NSCI_API_TOKEN=mysecret gunicorn "nsci:_make_api_app()" --bind 0.0.0.0:8080 --workers 4
```
