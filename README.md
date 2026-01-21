# Nolon

English | [中文](README_ZH.md)

Nolon is a powerful macOS application designed to streamline the management of skills for AI coding assistants like **Codex** and **Claude Code**. It acts as a centralized hub, allowing you to organize, install, and maintain your skills efficiently.

## 🚀 Key Features

*   **Centralized Repository**: Maintains a single source of truth for all your skills in `~/.nolon/skills/`.
*   **Clawdhub Integration** 🆕: Browse and install skills directly from [Clawdhub](https://clawdhub.com) remote repository.
*   **Broad Provider Support**:
    *   **Codex**, **Claude Code**, **OpenCode**, **GitHub Copilot**, **Gemini CLI**, **Antigravity**, **Cursor**.
*   **Flexible Configuration**:
    *   **Custom Paths**: Configure the skills directory used by each provider.
    *   **Installation Methods**: Choose between **Symbolic Link** (Live Sync) or **Copy** (Standard) for installation.
*   **Migration Assistant**: Automatically detects "orphaned" skills (physical files) in provider directories and helps you migrate them to Nolon's managed storage.
*   **Health Checks**: Identifies and repairs broken symlinks to keep your environment healthy.
*   **Rich Metadata Support**: Parses standard `SKILL.md` frontmatter to display version, description, and other details.
*   **Complete Folder Support**: Manages skills as complete folders, preserving auxiliary files like `scripts/` and `references/`.
*   **Internationalization**: Fully localized in **English** and **Chinese (Simplified)**.

## 🔄 Skills Management Workflow

### Local Skills
1.  **Import**: Import skills from local folders into Nolon's global storage.
2.  **Install**: Select a skill and toggle installation for target providers (e.g., Codex, Claude).
3.  **Migrate**: Use the "By Provider" view to find existing unmanaged skills and migrate them to Nolon's management.

### Remote Skills (Clawdhub)
1.  **Browse**: Click the cloud icon in toolbar to open Clawdhub browser.
2.  **Search**: Search for skills by name or browse the latest skills.
3.  **Install**: Select a skill and choose a provider to install to.
4.  **Auto-Sync**: Skills are downloaded to global storage, then linked/copied to provider.

## 🛠 Project Structure

The project follows a clean architecture:

*   **Models**: Domain entities (`Skill`, `Provider`, `RemoteSkill`, etc.) located in `Skills/Models`.
*   **Infrastructure**: Storage and system operations (`SkillRepository`, `SkillInstaller`, `ClawdhubService`) located in `Skills/Infrastructure`.
*   **Views**: SwiftUI user interface (`MainSplitView`, `RemoteSkillsBrowserView`) located in `Skills/Views`.
*   **App**: Entry point at `nolon/nolonApp.swift`.

## 🎨 Design System

We use a code-based color system located in `nolon/DesignSystem/AppColors.swift`.

**Rules:**
*   **Always** use `DesignSystem.Colors` instead of hardcoded `Color(...)` or system defaults.
*   **Do not** use `Color.blue`, `Color.white`, etc.
*   **Available Palette**:
    *   **Brand**: `DesignSystem.Colors.primary`, `secondary`
    *   **Backgrounds**: `DesignSystem.Colors.Background.canvas`, `surface`, `elevated`
    *   **Text**: `DesignSystem.Colors.Text.primary`, `secondary`, `tertiary`, `quaternary`
    *   **Status**: `DesignSystem.Colors.Status.info`, `success`, `warning`, `error`
*   **Dark Mode**: All colors automatically adapt to system appearance.

## 💻 Build and Run

1.  Open `nolon.xcodeproj` in Xcode 16+.
2.  Wait for Swift Package Manager to resolve dependencies (MarkdownUI).
3.  Select the **nolon** scheme and **My Mac** as the destination.
4.  Run the application (Cmd+R).

### Command Line Verification

You can verify the build using the provided helper script:

```bash
./build.sh
```

Or manually using `xcodebuild`:

```bash
xcodebuild -project nolon.xcodeproj -scheme nolon -configuration Release
```

## 📋 Requirements

*   macOS 15.0+
*   Xcode 16.0+ (for building)

## 🙏 Acknowledgments

This project is inspired by and references the following projects:

*   **CodexSkillManager**: [https://github.com/Dimillian/CodexSkillManager](https://github.com/Dimillian/CodexSkillManager)
*   **SkillsManager**: [https://github.com/tddworks/SkillsManager](https://github.com/tddworks/SkillsManager)
*   **Clawdhub**: [https://clawdhub.com](https://clawdhub.com) - Remote skills repository

