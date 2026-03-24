## nolon 2.1.8

### Changes
- Fixed resource center behavior so tapping the same skill repeatedly can reopen the detail pane reliably.
- Normalized git-based `skillsPaths` handling to consistently use directory paths, improving repository skill discovery stability.
- Hardened the GitHub Actions release workflow by importing signing certificates into an isolated keychain before running the release script.
- Updated release workflow Xcode setup to `26.3` to match current CI toolchain requirements.
