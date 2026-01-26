---
description: Release and distribute a new version of Nolon
---

1. Ensure you have the latest code and dependencies.
2. Run the release script with the version number:

```bash
./scripts/release.sh <version>
```
Example:
```bash
./scripts/release.sh 0.0.5
```

This script will:
- Update the version in Xcode project files.
- Build and sign the app for both Apple Silicon (arm64) and Intel (x86_64).
- Notarize the DMGs with Apple.
- Update `docs/appcast.xml` for Sparkle updates.
- **Auto-generate release notes** by comparing changes with the previous version tag.
- Commit and push changes.
- Create a GitHub release and upload the DMGs.
