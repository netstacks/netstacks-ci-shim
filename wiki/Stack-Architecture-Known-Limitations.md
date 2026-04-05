# Stack Architecture — Known Limitations

Things that don't work, can't work, or will bite you with the current design.
Not bugs to fix — architectural boundaries to be aware of.

---

## 1. ~~SNMP template will nuke your system config~~ — FIXED

Fixed. Schema path is `/openconfig-system:system` with default merge.
gNMI does `Set update` (merges in). XML template merges into `<system>`,
with `nc:operation="replace"` only on the `<snmp>` sub-element.
NTP/DNS/AAA are untouched.

---

## 2. gNMI cannot do mixed merge/replace in one template

NETCONF lets you put `nc:operation="replace"` on one element and merge
everywhere else in the same XML document. gNMI cannot — it's one operation
per path per `Set` call.

The PBR/FBF template works on NETCONF (replace the named filter, merge the
routing-instance binding). On gNMI, you'd need to split it into two services
with two schemas — one with `operation: replace`, one with `operation: merge`.

**Affects:** Any service that needs replace on one subtree and merge on another
within the same template. Only matters for native/vendor-specific templates
that touch multiple subtrees.

---

## 3. Schema `operation` only controls gNMI — NETCONF is template-driven

The `operation` field in the schema drives gNMI (`Set update` vs `Set replace`).
For NETCONF, the XML template's `nc:operation` attributes are what matters.

If a template creator sets `operation: replace` in the schema but forgets
`nc:operation="replace"` in the XML template (or vice versa), gNMI and NETCONF
will behave differently for the same service. There's no validation that they
agree.

**The rule:** Schema `operation` = gNMI behavior. Template `nc:operation` =
NETCONF behavior. The template creator must keep them in sync manually.

---

## 4. ~~No delete operation~~ — IMPLEMENTED

`nsci stack-delete` removes only the config that the stack created, with
per-list-item precision on both transports. No separate delete templates
needed — the deploy template handles both deploy and teardown.

**OpenConfig services (automatic):**
- **gNMI:** walks rendered JSON, builds `Set delete` per list entry
  (e.g., `.../neighbor[neighbor-address=172.16.0.1]`)
- **NETCONF:** injects `nc:operation="delete"` on list item elements
  (`<static>`, `<neighbor>`, `<server>`, etc.)

**Vendor-native services (operation swap):**
- **NETCONF:** swaps all `nc:operation="replace"` and `nc:operation="merge"`
  to `nc:operation="delete"` at runtime. Same deploy template, no extra files.
- **Requirement:** vendor-native templates must have explicit `nc:operation`
  on every operational element. This is validated at render time — templates
  without explicit operations are rejected before anything is pushed.

**Delete templates** (`delete.{platform}.{fmt}.j2`) are still supported as
optional overrides but are no longer required for any service.

---

## 5. eAPI and REST API transports are not implemented

Drivers exist for `eos-eapi` and `paloalto-panorama`, but
`transport_push_partial` only handles `gnmi` and `netconf`. Using a device
with eAPI or REST transport in a stack will raise `ValueError: partial push
not supported for transport 'eapi'`.

The `fw-security-rule` service (Palo Alto REST) cannot be deployed via
`stack-deploy` today.

---

## 6. ~~Validation is shallow~~ — IMPROVED

Validation now does recursive deep comparison (`_deep_check`). For gNMI
devices, it pulls the specific config section and compares all keys, values,
and list items (matched by key fields like `address`, `prefix`,
`neighbor-address`). Handles OpenConfig module prefix mismatches (e.g.,
`openconfig-system:servers` vs `servers`) and BGP community format
differences (Arista returns numeric `4259840100`, templates use `65000:100`).

**Remaining limitation:** NETCONF validation is still basic.

---

## 7. ~~Concurrent push to same device will race~~ — FIXED

Jobs targeting the same device are now serialized automatically. The thread
pool parallelizes across devices but pushes services to each device one at
a time. This prevents Arista's "existing write transaction in progress"
errors and NETCONF candidate lock conflicts.

Path collision detection (`_check_path_collisions`) also warns at render
time if two services target the same device + path.

---

## 8. gNMI rollback is a full config replace

When atomic deploy fails, commit-confirm devices auto-rollback (clean).
gNMI devices get rolled back by pushing the entire pre-flight config via
`transport_push_full` — a full `Set replace` at `/`. This is heavy, touches
everything, and could fail itself. If rollback fails, manual intervention
is needed.

---

## 9. ~~Template variable injection is not escaped~~ — FIXED

XML templates now use Jinja2 `autoescape=True`, which automatically escapes
`&`, `<`, `>`, and `"` in variable values. `netops&team` renders as
`netops&amp;team` in XML output. JSON templates are unaffected (no escaping
needed for JSON string values).

---

## 10. No template for a transport = error at render time

If a gNMI device is listed in a service that only has a NETCONF template
(like `pbr-voip` which only has `template.junos.xml.j2`), nsci will fail
at render time with "no template found." The error is clear, but there's
no upfront check when writing the stack — you find out when you render.

---

## 11. ~~BGP path is hardcoded to `network-instance[name=default]`~~ — FIXED

Schema paths now support Jinja2 variables. BGP and static-route schemas use
`{{ network_instance | default('default') }}` in their paths, so stacks can
target any VRF:

```yaml
path: /openconfig-network-instance:network-instances/network-instance[name={{ network_instance | default('default') }}]/...
```

Stack variables like `network_instance: ACME-VRF` are substituted at resolve
time.

---

## 12. Commit-confirm window is per-device, not per-service

If a device gets 3 services pushed, the commit-confirm timer starts on the
first push. All 3 pushes, plus validation, plus the confirm call must
complete within the timeout (default 120s). With many services or slow
validation, the timer could expire and auto-rollback before nsci confirms.

---

## 13. JSON templates produce different merge behavior than XML

gNMI `Set update` with a JSON list merges by list key. NETCONF merge with
XML merges by element presence. The actual merge semantics differ between
vendors and between gNMI/NETCONF implementations. The same template intent
can produce different results on different transports.

Example: Sending 2 NTP servers via merge. Arista gNMI might keep existing
servers. Junos NETCONF might replace the whole list. Depends on the
vendor's YANG implementation of the list type (ordered-by-user vs
ordered-by-system) and how they handle the merge.
