# Nolon

English | [中文](README_ZH.md)

Nolon is a macOS control plane for AI coding assistants.  
It manages your **skills**, **providers**, and **MCP configuration** in one place, then applies them consistently across tools like **Codex**, **Claude Code**, **Cursor**, and 20+ others.

Instead of treating skills as isolated files, Nolon treats your setup as an operational system:
*   One canonical storage at `~/.nolon/skills`
*   Deterministic install to each provider via symlink/copy
*   Remote distribution + local lifecycle (import, migrate, repair, update)
*   Built-in update channels for both the app (Sparkle) and managed content

## 📦 Download

*   **Latest release**: [v1.3.5](https://github.com/linhay/nolon/releases/latest)
*   **Appcast (Sparkle updates)**: [appcast.xml](https://linhay.github.io/nolon/appcast.xml)

## 🚀 Key Features

### 1) Provider Fleet Management
*   **Broad Provider Support** (25+):
    *   **Codex**, **Claude Code**, **OpenCode**, **GitHub Copilot**, **Gemini CLI**, **Antigravity**, **Cursor**, **Amp**, **Clawdbot**, **Cline**, **Command Code**, **Droid**, **Goose**, **Kilo**, **Kiro**, **MCPJam**, **OpenHands**, **Pi**, **Qoder**, **Qwen**, **Roo**, **Trae**, **Windsurf**, **Zencoder**, **Neovate**.
*   **Provider-level path mapping**: each provider can use its own target directory.
*   **Install strategy per provider**: choose **symlink** (live-sync) or **copy** (snapshot).

### 2) Skills Lifecycle Orchestration
*   **Centralized repository** at `~/.nolon/skills` as source of truth.
*   **Import + install + uninstall** across providers from a single UI.
*   **Migration assistant** for orphaned/manual skills found in provider directories.
*   **Health checks and repair** for broken symlinks and inconsistent install state.
*   **Structured metadata parsing** from `SKILL.md` frontmatter.
*   **Folder-native skills model** (keeps `scripts/`, `references/`, and side files intact).

### 3) Remote Distribution + MCP
*   **Clawdhub integration** for remote browsing and one-click install.
*   **Remote repositories** beyond Clawdhub (syncable repository model).
*   **MCP management** per provider, including remote MCP install flows.

### 4) Operational Tooling
*   **In-app update checks** for managed skills content.
*   **Sparkle app updates** for Nolon itself.
*   **Internationalized UI** in English and Simplified Chinese.

## 🔄 Workflow

### Local Lifecycle
1.  **Import**: Import skills from local folders into Nolon's global storage.
2.  **Install**: Select a skill and toggle installation for target providers (e.g., Codex, Claude).
3.  **Migrate**: Use the "By Provider" view to find existing unmanaged skills and migrate them to Nolon's management.
4.  **Repair**: Run health checks to detect and fix broken links/state drift.

### Remote Lifecycle
1.  **Browse**: Open remote browser (Clawdhub or configured repository source).
2.  **Search**: Find skills/MCPs by name or recent updates.
3.  **Install**: Pick provider target and install strategy.
4.  **Sync**: Pull remote changes into local canonical storage, then apply to providers.

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

### Git Submodules

This repo uses git submodules under `libs/`. Make sure to fetch them before building:

```bash
git submodule update --init --recursive
```

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
