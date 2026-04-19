# Security

## Reporting a vulnerability

Email **andrew.feng@frontiercommons.org** with:

- A description of the issue and its impact
- Steps to reproduce or a proof of concept
- The version of ShotMaker you're running

Please don't open a public GitHub issue for security vulnerabilities. I'll respond within a week and aim to ship a fix within 30 days of confirmation.

## Threat model

ShotMaker is a local-only utility. It has no server, no account system, and no network stack. The relevant attack surface is:

**What it has access to:**
- Your Desktop folder (required to watch for screenshots)
- Writes one SQLite database to `~/Library/Application Support/org.frontiercommons.shot-maker/`
- Sends macOS user notifications (no content beyond filename and auto-tag)

**What it doesn't do:**
- No outbound network connections
- No microphone, camera, or location access
- No clipboard access except when you explicitly trigger paste-to-ingest
- No access outside the Desktop folder and its own Application Support directory

**Local data security:**
- The SQLite database is at `~/Library/Application Support/org.frontiercommons.shot-maker/screenshots.db` with permissions `0700` on the containing directory
- OCR text is stored in plaintext in the database — this is necessary for search to work. Treat the database like you'd treat a folder of your screenshots
- Thumbnails are stored as JPEG blobs in the same database

**Hardened Runtime:**
The release build is compiled with Hardened Runtime enabled and the following exceptions explicitly disabled:
- `com.apple.security.cs.allow-jit`: false
- `com.apple.security.cs.allow-unsigned-executable-memory`: false
- `com.apple.security.cs.disable-library-validation`: false

**Notarization:**
Release builds are notarized by Apple and stapled. Gatekeeper will verify the signature on first launch.

## Known limitations

- The app is not sandboxed (App Store sandbox would require a different architecture for FSEvents directory watching with security-scoped bookmarks). This means it runs with your full user-level permissions.
- OCR text is stored unencrypted. If full-disk encryption (FileVault) is off, the database is readable to anyone with physical access to the machine.
