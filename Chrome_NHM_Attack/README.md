# Chrome Native Messaging Host Shadow Attack

## Overview

Chrome extensions talk to local applications through [Native Messaging Hosts](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging) (NMH). Each NMH is registered with a JSON manifest that tells Chrome which binary to launch when the extension calls `chrome.runtime.connectNative()`.

Chrome resolves NMH manifests from **two locations**, checked in order:

| Priority | Path | Scope |
|----------|------|-------|
| 1st (wins) | `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/` | User-level |
| 2nd | `/Library/Google/Chrome/NativeMessagingHosts/` | System-level |

If the same manifest name exists in both locations, the **user-level copy wins**. This is by design - Chrome does not warn, does not compare, and does not log the override.

This POC exploits that search order. It drops a user-level manifest that shadows any system-level NMH, redirecting Chrome through a wrapper script that intercepts all traffic before forwarding it to the real binary. **No root, no SIP bypass, no entitlements required.**

## How it works

```
┌────────────────────┐     stdio      ┌──────────────────┐     exec      ┌──────────────────┐
│  Chrome Extension   │ ────────────► │  Wrapper Script   │ ──────────► │  Real NMH Binary  │
│  (in browser)       │               │  (user-level)     │              │  (system-level)   │
└────────────────────┘               │  logs all I/O     │              └──────────────────┘
                                      └──────────────────┘
                                             │
                                             ▼
                                      /tmp/nmh_proof.txt
```

1. The POC creates the user-level NMH directory if it doesn't exist
2. Drops a shadow manifest (`com.example.nmh.json`) pointing to a wrapper script instead of the real binary
3. The wrapper logs proof of interception to `/tmp/nmh_proof.txt`
4. Then `exec`s the real binary with all original arguments - the extension works normally

The interception is completely transparent. The extension has no way to detect that traffic is being routed through a wrapper.

## Finding targets on your system

List all installed NMH manifests:

```bash
# system-level (installed by agents/apps)
ls /Library/Google/Chrome/NativeMessagingHosts/

# user-level (already shadowed or user-installed)
ls ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/
```

Read a manifest to get the fields you need:

```bash
cat /Library/Google/Chrome/NativeMessagingHosts/com.example.nmh.json
```

Example output:

```json
{
    "name": "com.example.nmh",
    "description": "Example NMH Bridge",
    "path": "/opt/example-agent/nmh-bridge",
    "type": "stdio",
    "allowed_origins": [ "chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/" ]
}
```

You need three values from this:
- `name` - the NMH identifier (also the filename without `.json`)
- `path` - the real binary to forward to
- `allowed_origins` - the Chrome extension ID

Edit the configuration section at the top of `nmh-shadow-poc.swift` with these values.

## Compile and run

```bash
# compile
swiftc nmh-shadow-poc.swift -o nmh-shadow-poc

# run - no sudo needed
./nmh-shadow-poc
```

Expected output:

```
[OK] Created NMH directory: /Users/you/Library/Application Support/Google/Chrome/NativeMessagingHosts
[OK] Shadow manifest written to /Users/you/Library/.../com.example.nmh.json
[OK] Wrapper written to /Users/you/Library/Application Support/nmh-wrapper.sh
[OK] Set executable permissions on wrapper

[DONE] NMH shadow deployed (no root required)
```

## Triggering the intercept

1. **Quit Chrome completely** - `Cmd+Q`, not just close the window. Chrome caches NMH manifest lookups for the lifetime of the process.
2. **Reopen Chrome** - the extension will now resolve the user-level manifest first.
3. **Use the extension normally** - any action that triggers `chrome.runtime.connectNative()` or `chrome.runtime.sendNativeMessage()` will hit the wrapper.
4. **Check the proof log:**

```bash
cat /tmp/nmh_proof.txt
```

```
[Wed May 14 10:23:15 CDT 2026] NMH shadow hit - intercepted com.example.nmh
[Wed May 14 10:23:18 CDT 2026] NMH shadow hit - intercepted com.example.nmh
```

## What an attacker can do from here

The wrapper sits in the middle of the stdio pipe between Chrome and the native binary. In a real engagement, the wrapper could:

- **Log all NMH traffic** - capture JSON messages flowing between extension and native app
- **Modify requests** - alter data before forwarding to the real binary
- **Modify responses** - alter data before returning to the extension
- **Exfiltrate data** - send copies of intercepted messages to an external server
- **Drop messages** - selectively block commands

This is especially impactful for:
- **Endpoint DLP agents** - intercept or disable browser DLP policy enforcement
- **Password managers** - capture autofill credentials in transit
- **Enterprise security extensions** - bypass browser-side security controls
- **SSO/Auth extensions** - intercept tokens and session data

## Cleanup

```bash
rm ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.example.nmh.json
rm ~/Library/Application\ Support/nmh-wrapper.sh
rm /tmp/nmh_proof.txt
```

## Detection

- Unexpected files in `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`
- NMH manifest `path` field pointing to a shell script instead of a signed binary
- User-level manifest that duplicates a system-level manifest name
- Monitoring `fs_usage` or Endpoint Security for writes to the NMH directory

## Why this works

Chrome's NMH resolution follows the [documented search order](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging#native-messaging-host-location) and intentionally allows user-level overrides. There is no signature verification on the binary pointed to by the manifest. Chrome trusts whatever `path` the manifest specifies - if it's executable, it runs.
