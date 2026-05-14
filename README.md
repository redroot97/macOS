# macOS

A collection of macOS security research POCs targeting endpoint management agents and browser trust boundaries. Each POC is a single-file Swift program with a dedicated README covering the attack, how to compile, run, trigger, and clean up.

## POCs

| POC | Path | Target | Privs |
| --- | --- | --- | --- |
| JAMF Binary Tampering | [JAMF/](JAMF/) | Replaces the JAMF agent binary with a wrapper that intercepts all MDM operations while keeping the agent functional. | root |
| Chrome NMH Shadow | [Chrome_NHM_Attack/](Chrome_NHM_Attack/) | Shadows a system-level Chrome Native Messaging Host manifest with a user-level copy, hijacking extension-to-native-app traffic. | none |

## Building

All POCs compile with `swiftc` (ships with Xcode Command Line Tools):

```bash
xcode-select --install   # if not already installed
swiftc <file>.swift -o <output>
```

No Xcode project, no dependencies.

## Repository layout

```
macOS/
|-- README.md
|-- JAMF/
|   |-- README.md
|   `-- jamf-tamper-poc.swift
`-- Chrome_NHM_Attack/
    |-- README.md
    `-- nmh-shadow-poc.swift
```

## Author

[@redroot97](https://github.com/redroot97) - offensive security engineer.

## Disclaimer

For authorized security research and red team engagements only.
