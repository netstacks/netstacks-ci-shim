# gNMI Vendor Reality Check: What Actually Works in Production

> **Last researched: April 2026**
> This is an honest, practitioner-focused assessment of gNMI support across vendors.
> It focuses on config management (Set RPC), not just telemetry (Subscribe).

---

## Executive Summary

**The honest truth:** gNMI is mature and battle-tested for **telemetry** (Subscribe). For **config management** (Set), it works but with significant vendor-specific gotchas. No two vendors implement it the same way. NETCONF remains more mature for transactional config management on most platforms. Nokia SR Linux is the notable exception where gNMI is the native, first-class interface.

The protocol spec itself has ambiguities (replace semantics, encoding expectations) that vendors interpret differently. OpenConfig model coverage is a patchwork -- BGP and interfaces are reasonably covered; everything else varies wildly.

---

## Vendor-by-Vendor Assessment

### Arista EOS

**gNMI Set (config push):** Works. Arista is one of the better gNMI implementations overall.

- **Full replace:** Works at subtree level. Replace is scoped to the specified path (children not in payload get removed, siblings are unaffected). Be careful with replace at broad paths -- you can accidentally erase config that exists outside OpenConfig's supported scope.
- **Encoding:** JSON and JSON_IETF supported. No PROTO for Set. When encoding is set to JSON or JSON_IETF, output returns as the eAPI model serialized as JSON.
- **OpenConfig model coverage:** Reasonable for core networking (BGP, interfaces, routing policy, VLANs, LLDP, network-instances). Arista publishes full YANG models on GitHub (`aristanetworks/yang`) with explicit deviations and augmentations per release. Many features still require Arista-native YANG. Check the path report at `eos.arista.com/path-report` for your release.
- **EOS native paths:** Supported via `origin: eos_native` through the Octa agent. This gives you access to Sysdb/Smash paths alongside OpenConfig, which is a significant advantage for features not covered by OC models.
- **Commit Confirmed:** Not supported via gNMI. The gNMI commit confirmed extension (spec v0.1.0 from 2023) is not yet widely implemented by any vendor.
- **Config persistence gotcha:** Prior to EOS 4.28.0F, gNMI Set operations were NOT automatically saved to startup-config. You must explicitly enable: `management api gnmi / transport grpc <n> / operation set persistence`. Without this, a reboot loses all gNMI-pushed config. Config is saved in native EOS syntax, not OpenConfig format.
- **Atomicity:** All gNMI Set transactions provide the same atomicity guarantees as CLI sessions.
- **Known gotchas:**
  - Replace can erase config outside OpenConfig's scope if that config overlaps with the replaced subtree
  - Arista returns every leaf value in a separate Notification message (unlike Cisco NX-OS which groups them) -- not a bug but affects client parsing
  - IPv6 zone-id suffix (`%<zone-id>`) is unsupported in YANG address types
  - Prior to EOS 4.24.0F, not all Smash paths were accessible through Octa
- **Is NETCONF better?** Both use the same OpenConfig agent backend (Octa). Feature parity is close. gNMI is Arista's preferred direction. NETCONF is fine but gNMI gets more development attention.

### Cisco IOS-XR

**gNMI Set:** Works, but NETCONF is more mature on this platform.

- **Full replace:** Supported. Replace semantics follow the spec (scoped to specified path).
- **Encoding:** JSON and JSON_IETF for Set operations. PROTO encoding does NOT support Get or Set RPCs -- only Subscribe. This is a significant limitation documented by Cisco.
- **Data precision problem:** Cisco documents a known issue where JSON and JSON_IETF encoding causes "premature wraps and other issues, causing loss of data precision" for numeric values. PROTO encoding fixes this but is only available for Subscribe. This means Set operations are stuck with the lossy encoding.
- **OpenConfig vs. native:** OpenConfig implementation varies by feature. Some features can be fully configured via OC, others require a mix of OC and native YANG. You should use Cisco native data models for features not supported by OpenConfig. IOS-XR ships YANG files that define supported models -- use `pyang` or the router itself via NETCONF to discover them.
- **Commit behavior:** IOS-XR requires a commit for gNMI Set operations to take effect (like NETCONF). This is actually a safety advantage.
- **Known issues:**
  - JSON_IETF keys must contain YANG prefixes where child namespace differs from parent (e.g., `oc-vlan:routed-vlan`) -- gets this wrong and the Set silently fails or errors
  - You cannot use both gNMI and NETCONF as management agents for OpenConfig simultaneously
  - gRPC/gNMI sandbox environments have been reported as non-responsive in community forums
  - Recent CVE (CVE-2025-20159): ACL processing issue affecting SSH, NETCONF, and gRPC -- management interface ACLs were not properly supported
  - Stricter input validation in recent releases means configs that worked before may now be rejected
- **Is NETCONF better?** Yes, generally. NETCONF is more mature on IOS-XR, has better tooling support, and full candidate-config/commit/rollback semantics. Use NETCONF for config management, gNMI for telemetry.

### Cisco IOS-XE

**gNMI Set:** Supported but with notable encoding limitations.

- **Encoding:** JSON and JSON_IETF for Set. PROTO encoding supported from IOS-XE 17.11.1 but ONLY for Subscribe, not Get/Set. BYTES and ASCII encodings are NOT supported (returns error).
- **Same data precision issue as IOS-XR:** JSON/JSON_IETF encoding has documented precision loss for float/double values.
- **JSON_IETF namespace requirement:** Must include YANG module prefix in keys where namespaces differ -- e.g., `oc-vlan:routed-vlan` in OpenConfig VLAN augmentations. This is a common source of errors.
- **OpenConfig support:** Extensive across recent releases (17.12+). Cisco IOS-XE supports OpenConfig, IETF, and native YANG models.
- **Is NETCONF better?** NETCONF has more complete transactional capabilities on IOS-XE. gNMI is catching up but NETCONF has a longer track record here.

### Cisco NX-OS (Nexus 9000/3000)

**gNMI Set:** GA and functional, with significant constraints.

- **Encoding for Set:** JSON and ASCII ONLY for replace operations. No JSON_IETF for Set. No PROTO for Set.
- **Path restrictions:**
  - Cannot mix OpenConfig and device YANG paths in a single SetRequest
  - Maximum 20 paths per SetRequest
  - For CLI-based Set::Replace, only 1 path allowed
  - 8 MB maximum gRPC message size
- **Union-Replace (NX-OS 10.6.3F+):** New feature allowing both OpenConfig JSON and CLI text config in a single Set request. CLI takes precedence on overlap. This is a practical workaround for the model coverage gap.
- **OpenConfig coverage:** Limited compared to IOS-XR. Many DC features require Cisco device-native YANG.
- **Concurrent session limits:** Max concurrent Get+Set sessions = configured gNMI concurrent calls minus 1.
- **Known gotchas:**
  - NX-OS implements a non-standard keepalive mechanism (empty notification messages) not in the gNMI spec -- client implementations may need special handling
  - The "JSON only" limitation for Set is a real constraint if you need JSON_IETF compliance
- **Is NETCONF better?** For NX-OS, NETCONF and gNMI are roughly comparable in maturity. Neither is great. REST API (NX-API) is often the most practical option for NX-OS automation.

### Juniper Junos

**gNMI Set:** Supported, but NETCONF is clearly the preferred protocol.

- **Classic Junos vs. Junos Evolved:** Both support gNMI. Feature releases lag slightly on Evolved (e.g., gNMI INITIAL_SYNC stats available in Junos 20.2R1 but Evolved 20.4R1). The management plane APIs (CLI, NETCONF, gNMI) are described as "highly consistent" between platforms.
- **Full replace:** Supported. Replace is scoped to the specified origin at the specified path.
- **Commit requirement:** Like IOS-XR, Junos requires a commit for gNMI Set operations. This provides rollback safety.
- **Encoding:** JSON_IETF and PROTO supported for Subscribe. Practical config management is typically done with JSON_IETF encoding.
- **OpenConfig coverage:** Juniper publishes an OpenConfig User Guide with model-to-release mapping tables. BGP, interfaces, routing policy, and network instances are well supported. Coverage has improved steadily.
- **Known issues:**
  - Juniper vMX does NOT support gNMI Get RPC -- you must use Subscribe RPC instead with protobuf encoding. This is a significant limitation for lab/testing environments.
  - Juniper uses proprietary gNMI extensions (registered extension IDs) for telemetry features
  - Some community reports of gNMI service configuration issues (INVALIDARGUMENT errors)
- **Is NETCONF significantly better?** Yes. Juniper literally invented NETCONF. Their NETCONF implementation is the gold standard -- candidate config, confirmed commit, rollback, full transaction semantics. If you are doing config management on Juniper, use NETCONF. Use gNMI for telemetry streaming.

### Nokia SR Linux

**gNMI Set:** Excellent. This is the best gNMI implementation in the industry.

- **First-class interface:** SR Linux was built around gNMI from the ground up. Nokia EDA (Event Driven Automation) uses gNMI as its primary communication protocol for discovery, onboarding, and management.
- **Set operations:** Full support for delete, replace, and update. Operations are processed in the order listed.
- **Replace semantics:** Omitted values that were previously set are deleted. Omitted values with defaults get their defaults. CLI origin replace is treated as full device configuration replacement.
- **Encoding:** JSON_IETF, PROTO, and ASCII supported.
- **Multi-origin support:** Three origins available -- `srlinux_native`, `openconfig`, and `srlinux_cli`. SR Linux intrinsically links all origins so changes in one model automatically sync to others. This is a deviation from the gNMI spec but is incredibly practical.
- **OpenConfig coverage:** Good for data center use cases. SR Linux does built-in translation between native and OC models, so config pushed via OC can be viewed natively and vice versa. However, like all vendors, OC models cannot cover every vendor-specific feature.
- **Limitations:**
  - Delete operations not supported with CLI origin
  - Only one CLI replace operation per SetRequest
  - Subscriptions cannot be modified in-flight (must create new Subscribe RPC)
- **Gaps:** Very few for DC networking use cases. If you are in a Nokia SR Linux environment, gNMI is the way to go.

### Nokia SR OS (Classic)

**gNMI Set:** Mature and production-ready.

- **Model-driven architecture:** SR OS has been transitioning from classic CLI to model-driven interfaces. Starting SR OS release 23, all new routers default to MD-CLI. Mixed mode allows configuration via classic CLI and model-driven interfaces (MD-CLI, NETCONF, gNMI) simultaneously.
- **YANG foundation:** All model-driven interfaces share the same underlying YANG modules. NETCONF, gNMI, and MD-CLI all render from the same models, meaning feature parity between transport protocols.
- **OpenConfig:** Available when enabled with `configure system management-interface yang-modules openconfig-modules`. Not enabled by default.
- **Is NETCONF better?** They are essentially equivalent on SR OS since they share the same YANG backend. NETCONF may have slightly more tooling support in the broader ecosystem, but gNMI works well.

### HPE/Aruba (AOS-CX)

**gNMI:** Supported as of AOS-CX 10.14+.

- **Capabilities:** Supports all four gNMI RPCs: Capabilities, Get, Set, and Subscribe. VRF-aware with role-based access control.
- **Configuration:** Enable with `gnmi vrf default` in config mode.
- **Primary interface:** REST API is the primary programmatic interface for AOS-CX (100% REST API coverage is a design goal). gNMI is a secondary option. The REST API is more mature and better documented.
- **NETCONF:** Limited information found. REST API is clearly the focus.
- **Recommendation:** Use REST API for config management on AOS-CX. gNMI is available but REST is where HPE/Aruba invests.

### Palo Alto

**gNMI:** Yes, via the OpenConfig plugin.

- **Implementation:** The OpenConfig plugin implements a gNMI server on port 9339 supporting Set, Get, Subscribe, and Capabilities.
- **Set behavior:** Changes take effect immediately as part of an atomic multi-request operation. If any part is rejected, all operations revert. This is good transactional behavior.
- **Model coverage:** OpenConfig models support up to Layer 4 networking. Not exhaustive -- check the model support matrix per plugin version.
- **Limitations:**
  - Not supported in FIPS-CC mode
  - Only single-level wildcards in paths (no multi-level)
  - Runs as a separate plugin, not native to PAN-OS
  - Security advisory: command injection vulnerability found in the OpenConfig plugin (GHSA-73px-m3vw-mr35)
- **Is REST API better?** Yes, the PAN-OS XML/REST API is the primary and most mature automation interface. The OpenConfig plugin is an add-on for environments that want gNMI standardization. Most Palo Alto automation uses the native API or Ansible modules.

### F5

**gNMI/NETCONF:** Not supported.

- **Primary interface:** iControl REST API is the definitive automation interface for BIG-IP. F5's entire automation ecosystem (AS3, FAST, Terraform provider, Ansible modules) is built on iControl REST.
- **No evidence of gNMI or NETCONF support** in any F5 documentation or community resources.
- **Recommendation:** Use iControl REST or the declarative AS3 API. Do not expect gNMI support.

### Fortinet

**gNMI:** Not supported natively.

- **REST API:** The primary automation interface. Available since FortiOS 5.4 with good coverage of device configuration.
- **NETCONF:** Not natively supported. There is a community bridge tool (`fortinet-solutions-cse/netconf-rest` on GitHub) that translates NETCONF requests to REST API calls. Last updated 2022 -- not actively maintained.
- **Recommendation:** Use the FortiOS REST API. There is no gNMI path here.

### Dell OS10 / Enterprise SONiC

**gNMI:** Supported on Enterprise SONiC.

- **Enterprise SONiC:** Supports REST API and gNMI. Includes streaming telemetry via gNMI.
- **NETCONF:** Limited/developing. Not a primary interface on Dell SONiC platforms. Other SONiC variants (e.g., AsterNOS) have added NETCONF support separately.
- **OS10 vs. SONiC:** These are separate operating systems. SONiC is the forward-looking platform.
- **Note:** Community SONiC (not Dell Enterprise) has its own gNMI implementation via the sonic-gnmi container.

### Cumulus Linux / NVIDIA

**gNMI:** Telemetry streaming ONLY (Subscribe). No evidence of Set support.

- **gNMI agent:** Relies on NVUE service for data collection. Supports Capabilities and STREAM subscribe requests. Documentation across all Cumulus versions (4.3 through 5.16) categorizes gNMI under "Monitoring and Troubleshooting," not configuration.
- **NETCONF:** Not supported.
- **Primary interface:** NVUE REST API is the definitive configuration management interface. NVUE provides GET, PATCH, DELETE operations with a declarative configuration model.
- **Recommendation:** Use NVUE REST API for config management. Use gNMI for telemetry only.

---

## Cross-Vendor Issues

### Encoding Chaos

| Vendor | Set Encoding | Subscribe Encoding |
|--------|-------------|-------------------|
| Arista EOS | JSON, JSON_IETF | JSON, JSON_IETF |
| Cisco IOS-XR | JSON, JSON_IETF | JSON, JSON_IETF, PROTO |
| Cisco IOS-XE | JSON, JSON_IETF | JSON, JSON_IETF, PROTO (17.11.1+) |
| Cisco NX-OS | JSON, ASCII only | JSON |
| Juniper Junos | JSON_IETF | JSON_IETF, PROTO |
| Nokia SR Linux | JSON_IETF, PROTO, ASCII | JSON_IETF, PROTO, ASCII |
| Nokia SR OS | JSON_IETF | JSON_IETF |

**Key pain point:** If you want a single encoding that works everywhere for Set operations, **JSON_IETF** is the closest to universal, but NX-OS only supports plain JSON for Set. You will need per-vendor encoding configuration.

### The "origin" Field Problem

The `origin` field in gNMI Path messages is supposed to disambiguate between data models (e.g., `openconfig` vs. `native`). In practice:

- **Arista:** Uses `eos_native` for native paths, default (empty) for OpenConfig
- **Nokia SR Linux:** Uses `srlinux_native`, `openconfig`, and `srlinux_cli` -- and uniquely links all origins so changes sync automatically
- **Cisco NX-OS:** Cannot mix OpenConfig and device YANG paths in a single request
- **Cisco IOS-XR:** Supports both but you cannot use gNMI and NETCONF simultaneously for OpenConfig
- **Juniper:** Uses origin to scope replace operations

**The real problem:** There is no standardized way to disambiguate identical paths between supported models. The gNMI spec lacks a standard approach, and very few gNMI servers support using YANG module names in prefix/path fields for disambiguation.

### Replace vs. Update Semantics

Per spec:
- **Update:** Merges/modifies values at the specified path. Existing children not in the payload are preserved.
- **Replace:** Substitutes the entire value at the path. Children not in the payload are removed (set to defaults or deleted).

**Vendor differences:**
- Behavior of omitted data elements varies: some vendors delete them, others reset to defaults, others preserve them depending on whether they were previously explicitly set
- Nokia SR Linux: omitted previously-set values are deleted; omitted default values get defaults
- The spec acknowledges ambiguity around what happens when Update and Replace fields intersect in the same SetRequest (GitHub issue #134)
- Root-level replace has platform-specific "protected" items (gNSI, bootz configs) that cannot be affected

### OpenConfig Model Coverage Reality

**Well-supported across most vendors:**
- `openconfig-interfaces` (basic interface config/state)
- `openconfig-bgp` (BGP configuration)
- `openconfig-routing-policy` (route policy)
- `openconfig-network-instance` (VRFs, routing instances)
- `openconfig-lldp`

**Poorly or inconsistently supported:**
- ACLs (wide variation in implementation)
- QoS (minimal real-world OC support)
- Segment Routing / MPLS (mostly native YANG)
- Platform-specific features (optics, hardware, etc.)
- Security features (AAA, TACACS, etc. -- partial at best)
- Multicast
- EVPN/VXLAN (mostly vendor-native)

**The practical reality:** Even for "supported" models, vendors publish deviations files showing which leaves they do and do not implement. Expect 60-80% coverage of any given OpenConfig model, with the missing 20-40% being the parts you actually need for your specific deployment.

### gNMI Commit Confirmed

The gNMI commit confirmed extension was specified in September 2023 (v0.1.0) and merged into the openconfig/gnmi and openconfig/reference repos in August 2024. It provides NETCONF-style auto-rollback: push config, if not confirmed within a timer (default 10 minutes), the device rolls back.

**Vendor support as of April 2026:** Essentially none confirmed in public documentation. This is a spec that exists on paper but has not been widely implemented. If you need commit-confirmed safety, use NETCONF (which has had this for 20 years).

---

## The Big Question: Is gNMI Ready for Config Management?

### Where gNMI works well for config:
- **Nokia SR Linux** -- built for it, first-class support
- **Arista EOS** -- solid implementation, good native path support
- **Nokia SR OS** -- mature model-driven architecture
- **Single-vendor environments** where you can standardize on one encoding and model set

### Where you should use NETCONF instead:
- **Juniper Junos** -- NETCONF is unambiguously superior
- **Cisco IOS-XR** -- NETCONF is more mature with full transaction semantics
- **Cisco IOS-XE** -- NETCONF has better track record
- **Any environment requiring commit-confirmed rollback safety**
- **Multi-vendor environments** where encoding and model consistency matters

### Where neither gNMI nor NETCONF is the answer:
- **Cisco NX-OS** -- NX-API REST is often most practical
- **HPE/Aruba AOS-CX** -- REST API is primary
- **F5** -- iControl REST only
- **Fortinet** -- REST API only
- **Cumulus/NVIDIA** -- NVUE REST API only
- **Palo Alto** -- native XML/REST API is primary (OpenConfig plugin is a secondary option)

### The practitioner consensus:
gNMI is **excellent for telemetry** and **adequate for config management** if you are willing to invest in per-vendor encoding/model handling. It is NOT a drop-in replacement for NETCONF's config management capabilities. The toolchain (gnmic, pygnmi) is good. The vendor implementations are the weak link.

For a multi-vendor config management system, expect to maintain:
- Per-vendor encoding settings
- Per-vendor origin/path mappings
- A mix of OpenConfig and native YANG models
- Vendor-specific workarounds for Set behavior differences
- Fallback to NETCONF or REST for features/platforms where gNMI falls short

---

## Key Sources

- [Arista OpenConfig Configuration Guide](https://aristanetworks.github.io/openmgmt/configuration/openconfig/)
- [Arista YANG Models Repository](https://github.com/aristanetworks/yang)
- [Cisco NX-OS 10.6 gNMI Guide](https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/106x/programmability/cisco-nexus-9000-series-nx-os-programmability-guide-106x/m-gnmi.html)
- [Cisco IOS-XE 17.18 gNMI Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/1718/b-1718-programmability-cg/gnmi.html)
- [Cisco IOS-XR gNMI Configuration](https://www.cisco.com/c/en/us/support/docs/ios-nx-os-software/ios-xr-software/221690-configure-gnmi-and-implement-pyang-in-io.html)
- [Nokia SR Linux gNMI Documentation](https://documentation.nokia.com/srlinux/25-3/books/system-mgmt/gnmi.html)
- [Nokia SR OS Model-Driven Interfaces](https://infocenter.nokia.com/public/7750SR217R1A/topic/com.sr.system.mgmt/html/mgmtinterfaces.html)
- [Juniper Junos OpenConfig User Guide](https://www.juniper.net/documentation/us/en/software/junos/open-config/open-config.pdf)
- [Palo Alto OpenConfig Support](https://docs.paloaltonetworks.com/openconfig/1-1/openconfig-admin/getting-started/about-pan-os-openconfig-support)
- [HPE Aruba AOS-CX gNMI](https://arubanetworking.hpe.com/techdocs/AOS-CX/10.17/HTML/monitoring_6300-6400/Content/Chp_gNMI/gnmi.htm)
- [OpenConfig gNMI Specification](https://github.com/openconfig/reference/blob/master/rpc/gnmi/gnmi-specification.md)
- [gNMI Commit Confirmed Spec](https://github.com/openconfig/reference/blob/master/rpc/gnmi/gnmi-commit-confirmed.md)
- [gNMI Set Replace Subtree Discussion](https://github.com/openconfig/reference/issues/135)
- [gNMI Mixed Schema Documentation](https://www.openconfig.net/docs/gnmi/mixed-schema/)
- [Practical gNMI Blog (mayuresh82)](https://mayuresh82.github.io/2021/12/23/gnmi_practical/)
- [Cisco YANG Model Selection Blog](https://blogs.cisco.com/developer/which-yang-model-to-use)
- [gNMI Interoperability Testing - Cisco Community](https://community.cisco.com/t5/crosswork-automation-hub-blogs/gnmi-openconfig-telemetry-interoperability-testing/ba-p/4891395)
- [SReXplore 2025: Vendor Neutral Config with OpenConfig and gNMI](https://srexplore.srexperts.net/nos/srlinux/beginner/b-srl-oc/)
- [Cumulus Linux gNMI Streaming](https://docs.nvidia.com/networking-ethernet-software/cumulus-linux-516/Monitoring-and-Troubleshooting/gNMI-Streaming/)
- [Dell Enterprise SONiC Spec Sheet](https://www.delltechnologies.com/asset/en-hk/products/networking/technical-support/dell-networking-spec-sheet-sonic.pdf)
