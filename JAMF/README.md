# JAMF Binary Tampering POC

Replaces the JAMF agent binary (`/usr/local/jamf/bin/jamf`) with a wrapper script that logs every invocation before passing through to the real binary.

Demonstrates that an attacker with root can silently intercept all JAMF policy runs, inventory submissions, and MDM check-ins on a managed Mac.

## What it does

1. Backs up the original `jamf` binary to `jamf.real`
2. Drops a bash wrapper in its place
3. Wrapper logs timestamp + arguments to `/tmp/JAMF_proof.txt`, then `exec`s the real binary

JAMF continues to function normally — the tampering is transparent.

## Usage

```bash
# compile
swiftc jamf-tamper-poc.swift -o jamf-tamper-poc

# run (needs root since /usr/local/jamf/bin is root-owned)
sudo ./jamf-tamper-poc

# trigger a policy run to prove it works
sudo jamf policy

# check proof
cat /tmp/JAMF_proof.txt
```

## Cleanup

```bash
sudo mv /usr/local/jamf/bin/jamf.real /usr/local/jamf/bin/jamf
rm /tmp/JAMF_proof.txt
```

## Impact

- Silent interception of all MDM commands
- Policy bypass / selective execution
- Credential harvesting from JAMF policy payloads
- Persistence that survives JAMF policy runs (since the wrapper calls through to the real binary)

## Detection

- File hash mismatch on `/usr/local/jamf/bin/jamf` (it's now a bash script, not a Mach-O)
- `file /usr/local/jamf/bin/jamf` returns "ASCII text" instead of "Mach-O 64-bit executable"
- Presence of `jamf.real` alongside `jamf`
