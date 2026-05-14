# Chrome Native Messaging Host Shadow Attack

Hijacks Chrome's Native Messaging Host (NMH) mechanism by placing a user-level config that shadows the system-level Aternity extension bridge. **No root required.**

Chrome resolves NMH manifests from `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/` before checking system paths. This POC exploits that search order to intercept all NMH traffic for the Aternity agent.

## What it does

1. Creates the user-level NMH directory (if it doesn't exist)
2. Drops a shadow `com.aternity.fpi.json` pointing to a wrapper script
3. Wrapper logs proof of interception to `/tmp/nmh_proof.txt`, then `exec`s the real Aternity binary

The Aternity extension continues working normally — the interception is transparent.

## Usage

```bash
# compile
swiftc nmh-shadow-poc.swift -o nmh-shadow-poc

# run (no root needed - writes to user Library)
./nmh-shadow-poc

# restart Chrome completely (quit + reopen)
# then check proof
cat /tmp/nmh_proof.txt
```

## Cleanup

```bash
rm ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.aternity.fpi.json
rm ~/Library/Application\ Support/wrapper.sh
rm /tmp/nmh_proof.txt
```

## Impact

- Intercept all data flowing between Chrome extension and native agent
- No privilege escalation needed — runs as the current user
- Applies to any NMH, not just Aternity (Endpoint DLP agents, password managers, etc.)
- Persists across Chrome restarts

## Detection

- Unexpected files in `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`
- NMH manifest pointing to a non-standard binary path
- Wrapper scripts in `~/Library/Application Support/`
