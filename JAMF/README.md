# JAMF Binary Tampering

## Overview

JAMF Pro is one of the most common MDM solutions for macOS in enterprise environments. The JAMF agent binary lives at `/usr/local/jamf/bin/jamf` and handles all communication with the JAMF Pro server - policy execution, inventory collection, check-ins, software installs, and configuration profiles.

This POC replaces the `jamf` binary with a bash wrapper that intercepts every invocation, logs it, and then passes through to the original binary. JAMF continues to function normally - the tampering is completely transparent to the MDM server, the admin console, and the end user.

## How it works

```
                Before tampering                          After tampering

┌──────────────┐     exec      ┌──────────┐    ┌──────────────┐    exec     ┌──────────────┐    exec     ┌──────────┐
│  launchd /    │ ────────────► │  jamf    │    │  launchd /    │ ─────────► │  jamf         │ ─────────► │  jamf    │
│  sudo / MDM   │               │  binary  │    │  sudo / MDM   │            │  (wrapper)    │            │  .real   │
└──────────────┘               └──────────┘    └──────────────┘            │  logs args    │            └──────────┘
                                                                            └──────┬───────┘
                                                                                   │
                                                                                   ▼
                                                                            /tmp/JAMF_proof.txt
```

1. The original `jamf` binary is moved to `jamf.real` in the same directory
2. A bash wrapper script is written to the original `jamf` path
3. The wrapper logs the timestamp and all arguments to `/tmp/JAMF_proof.txt`
4. Then `exec`s `jamf.real` with all original arguments - JAMF functions normally

Since the wrapper calls through to the real binary, JAMF inventory checks still report a "healthy" agent, policy runs still succeed, and the MDM server sees normal check-in behavior.

## Prerequisites

- **Root access** - `/usr/local/jamf/bin/` is owned by root
- **Target must have JAMF installed** - verify with `ls /usr/local/jamf/bin/jamf`
- **SIP does not protect this path** - `/usr/local/` is not covered by System Integrity Protection

## Compile

```bash
swiftc jamf-tamper-poc.swift -o jamf-tamper-poc
```

This produces a standalone Mach-O binary. No Xcode project needed, just the Swift compiler (ships with Xcode Command Line Tools).

## Run

```bash
# requires root since /usr/local/jamf/bin is root-owned
sudo ./jamf-tamper-poc
```

Expected output:

```
[OK] Moved original jamf to /usr/local/jamf/bin/jamf.real
[OK] Wrapper script written to /usr/local/jamf/bin/jamf
[OK] Set executable permissions on wrapper

[DONE] JAMF tampering POC deployed
  Proof log: /tmp/JAMF_proof.txt
  Run 'sudo jamf policy' to trigger
  Cleanup: sudo mv /usr/local/jamf/bin/jamf.real /usr/local/jamf/bin/jamf
```

## Triggering the intercept

JAMF calls the agent binary automatically on a regular schedule (typically every 15 minutes via the `com.jamfsoftware.task.1` LaunchDaemon). You can also trigger it manually:

```bash
# manual policy run
sudo jamf policy

# manual inventory submission
sudo jamf recon

# manual check-in
sudo jamf manage
```

Every invocation goes through the wrapper. Check the proof log:

```bash
cat /tmp/JAMF_proof.txt
```

```
[Wed May 14 10:15:02 CDT 2026] JAMF Tampering Success - args: policy
[Wed May 14 10:15:45 CDT 2026] JAMF Tampering Success - args: recon
[Wed May 14 10:30:01 CDT 2026] JAMF Tampering Success - args: policy -event login
```

## What an attacker can do from here

The wrapper sits at the choke point for all JAMF operations. In a real engagement, it could:

- **Log all MDM commands** - see exactly what policies are being pushed, what scripts are running, what packages are being installed
- **Selectively block policies** - drop `jamf policy` calls while letting `jamf recon` through so the agent still reports healthy
- **Modify arguments** - change policy triggers, redirect package installs
- **Intercept credentials** - JAMF policies can carry scripts with embedded credentials, API keys, or configuration secrets
- **Persist across JAMF remediation** - since `jamf recon` and `jamf policy` both run through the wrapper, even JAMF's own self-healing mechanisms go through the attacker's code first
- **Maintain stealth** - the MDM server sees normal check-ins because the wrapper forwards everything to the real binary

## Why the MDM server doesn't notice

JAMF Pro server validates that the agent checks in on schedule, runs policies, and returns inventory data. It does **not**:

- Verify the hash of the local `jamf` binary
- Check whether `/usr/local/jamf/bin/jamf` is a Mach-O or a script
- Detect the presence of `jamf.real` alongside `jamf`
- Validate code signatures on the agent binary at runtime

As long as the wrapper forwards calls to the real binary, the server is satisfied.

## Cleanup

```bash
sudo mv /usr/local/jamf/bin/jamf.real /usr/local/jamf/bin/jamf
rm /tmp/JAMF_proof.txt
```

This restores the original binary. Verify with:

```bash
file /usr/local/jamf/bin/jamf
# should say "Mach-O 64-bit executable arm64" (not "ASCII text")
```

## Detection

| Method | What to look for |
|--------|-----------------|
| File type check | `file /usr/local/jamf/bin/jamf` returns "ASCII text" instead of "Mach-O executable" |
| Hash comparison | Binary hash doesn't match known JAMF agent hashes from JAMF Pro server |
| Presence of backup | `jamf.real` exists alongside `jamf` in `/usr/local/jamf/bin/` |
| Endpoint Security | `ES_EVENT_TYPE_NOTIFY_RENAME` or `ES_EVENT_TYPE_NOTIFY_WRITE` on `/usr/local/jamf/bin/jamf` |
| Log monitoring | Unexpected writes to `/tmp/JAMF_proof.txt` or whatever log path the attacker uses |
| Code signature | `codesign -v /usr/local/jamf/bin/jamf` fails (bash script has no signature) |
