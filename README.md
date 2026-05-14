# macOS

macOS security research — proof-of-concept exploits targeting endpoint management agents and browser trust boundaries on macOS.

These POCs demonstrate real attack paths that work against enterprise Mac deployments. They focus on trust assumptions that macOS and third-party agents make about file system state, binary integrity, and search order resolution.

---

## POCs

### [JAMF Binary Tampering](JAMF/)

Replaces the JAMF agent binary with a transparent wrapper that intercepts every MDM operation — policy runs, inventory submissions, check-ins — while the MDM server continues to see a healthy agent. The wrapper logs all activity and forwards calls to the real binary.

- **Privileges**: root
- **SIP bypass**: not needed (`/usr/local/` is not SIP-protected)
- **Detection risk**: low — JAMF Pro does not verify the hash or file type of its own agent binary at runtime
- **Impact**: full visibility into MDM commands, selective policy blocking, credential interception from policy scripts

### [Chrome NMH Shadow Attack](Chrome_NHM_Attack/)

Exploits Chrome's Native Messaging Host resolution order to hijack the communication channel between a Chrome extension and its native companion app. A user-level manifest shadows the system-level one, redirecting traffic through a wrapper script.

- **Privileges**: none (user-level write only)
- **Target**: any NMH-based extension — endpoint DLP, password managers, enterprise security agents, SSO helpers
- **Detection risk**: low — Chrome does not log NMH resolution, does not verify binary signatures, and intentionally allows user-level overrides
- **Impact**: intercept, modify, or drop all data flowing between the browser extension and the native application

---

## Structure

```
macOS/
├── JAMF/
│   ├── jamf-tamper-poc.swift       # JAMF agent binary replacement
│   └── README.md                   # full writeup + compile + cleanup
├── Chrome_NHM_Attack/
│   ├── nmh-shadow-poc.swift        # generic NMH shadow attack
│   └── README.md                   # full writeup + targeting + cleanup
└── README.md                       # this file
```

## Build

Both POCs are single-file Swift programs. Compile with:

```bash
swiftc JAMF/jamf-tamper-poc.swift -o jamf-tamper-poc
swiftc Chrome_NHM_Attack/nmh-shadow-poc.swift -o nmh-shadow-poc
```

Requires Xcode Command Line Tools (`xcode-select --install`). No Xcode project, no dependencies.

## Disclaimer

For authorized security research and red team engagements only. Don't run these against systems you don't own or aren't paid to test.
