# Nolon

## What this app is
Nolon is a macOS application designed to manage skills for AI coding assistants like Codex and Claude Code. It provides a centralized repository for your skills and installs them to specific providers using symbolic links, ensuring a clean and efficient management workflow.

## Features
- **Global Skill Storage**: Manages a single source of truth for all skills in `~/.nolon/skills/`.
- **Flexible Installation**: Supports multiple installation methods:
    - **Symlink**: Creates symbolic links (recommended for live updates).
    - **Copy**: Physically copies skill files to the provider directory.
- **Provider Support**:
    - Supports: **Codex**, **Claude Code**, **OpenCode**, **GitHub Copilot**, **Gemini CLI**, **Antigravity**, **Cursor**.
    - **Customizable Paths**: Users can configure the skills directory path for each provider.
- **Migration Assistant**: Detects "orphaned" skills (physical files) in provider directories and migrants them to global storage.
- **Health Checks**: Automatically detects and repairs broken symlinks.
- **Rich Metadata**: Supports parsing standard `SKILL.md` frontmatter and tracking installation state.
- **Folder Support**: Manages skills as complete folders, preserving `scripts/`, `references/`, and other auxiliary files.
- **Internationalization**: Supports English and Simplified Chinese (zh-Hans).

## Project Structure
- **App**: `nolon/nolonApp.swift` - SwiftUI App entry point.
- **Skills Management**:
  - `Skills/Models`: Domain models (`Skill`, `SkillProvider`, `SkillMetadata`).
  - `Skills/Infrastructure`: Logic for storage, parsing, and symlinking (`SkillRepository`, `SkillInstaller`).
  - `Skills/Views`: SwiftUI views for browsing and managing skills.

## Design System
We use a code-based color system located in `nolon/DesignSystem/AppColors.swift`.

**Rules:**
- **Always** use `DesignSystem.Colors` instead of hardcoded `Color(...)` or system defaults.
- **Do not** use `Color.blue`, `Color.white`, etc.
- **Available Palette**:
    - **Brand**: `DesignSystem.Colors.primary`, `secondary`
    - **Backgrounds**: `DesignSystem.Colors.Background.canvas`, `surface`, `elevated`
    - **Text**: `DesignSystem.Colors.Text.primary`, `secondary`, `tertiary`, `quaternary`
    - **Status**: `DesignSystem.Colors.Status.info`, `success`, `warning`, `error`
- **Dark Mode**: All colors automatically adapt to system appearance.

## Build and run
1. Open `nolon.xcodeproj` in Xcode.
2. Ensure the build target is set to "My Mac".
3. Run (Cmd+R).

## Command Line Verification
You can verify the build using the provided helper script:

```bash
./build.sh
```

Or manually using `xcodebuild`:

```bash
xcodebuild -project nolon.xcodeproj -scheme nolon -configuration Release
```


## Skills Management Workflow
1. **Import**: Import skills from local folders into Nolon's global storage.
2. **Install**: Select a skill and toggle installation for Codex or Claude.
3. **Migrate**: Use the "By Provider" view to find existing skills and migrate them to Nolon's management.

## Contributing
When adding new features, please follow the Clean Architecture principles used in the `Skills` module, separating Domain models from Infrastructure implementation and UI Views.
