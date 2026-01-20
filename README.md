# Nolon

Nolon is a powerful macOS application designed to streamline the management of skills for AI coding assistants like **Codex** and **Claude Code**. It acts as a centralized hub, allowing you to organize, install, and maintain your skills efficiently.

## 🚀 Key Features

*   **Centralized Repository**: Maintains a single source of truth for all your skills in `~/.nolon/skills/`.
*   **Broad Provider Support**:
    *   **Codex**, **Claude Code**, **OpenCode**, **GitHub Copilot**, **Gemini CLI**, **Antigravity**.
*   **Flexible Configuration**:
    *   **Custom Paths**: Configure the skills directory used by each provider.
    *   **Installation Methods**: Choose between **Symbolic Link** (Live Sync) or **Copy** (Standard) for installation.
*   **Migration Assistant**: Automatically detects "orphaned" skills (physical files) in provider directories and helps you migrate them to Nolon's managed storage.
*   **Health Checks**: Identifies and repairs broken symlinks to keep your environment healthy.
*   **Rich Metadata Support**: Parses standard `SKILL.md` frontmatter to display version, description, and other details.
*   **Complete Folder Support**: Manages skills as complete folders, preserving auxiliary files like `scripts/` and `references/`.
*   **Internationalization**: Fully localized in **English** and **Chinese (Simplified)**.

## 🛠 Project Structure

The project follows a clean architecture:

*   **Models**: Domain entities (`Skill`, `SkillProvider`, etc.)
*   **Infrastructure**: Storage and system operations (`SkillRepository`, `SkillInstaller`)
*   **Views**: SwiftUI user interface (`SkillManagerView`, `SkillListView`)

## 💻 Build and Run

1.  Open `nolon.xcodeproj` in Xcode 16+.
2.  Wait for Swift Package Manager to resolve dependencies (MarkdownUI).
3.  Select the **nolon** scheme and **My Mac** as the destination.
4.  Run the application (Cmd+R).

## 📋 Requirements

*   macOS 15.0+
*   Xcode 16.0+ (for building)

## 🙏 Acknowledgments

This project is inspired by and references the following projects:

*   **CodexSkillManager**: [https://github.com/Dimillian/CodexSkillManager](https://github.com/Dimillian/CodexSkillManager)
*   **SkillsManager**: [https://github.com/tddworks/SkillsManager](https://github.com/tddworks/SkillsManager)

