# Nolon

English | [中文](README_ZH.md)

Nolon 是一款强大的 macOS 应用程序，专为简化 AI 编程助手（如 **Codex** 和 **Claude Code**）的 Skills 管理而设计。它作为一个中心化枢纽，让您可以高效地组织、安装和维护您的 Skills。

## 🚀 主要功能

*   **中心化仓库**：在 `~/.nolon/skills/` 中维护所有 Skills 的单一事实来源。
*   **广泛的 Provider 支持**：
    *   **Codex**, **Claude Code**, **OpenCode**, **GitHub Copilot**, **Gemini CLI**, **Antigravity**, **Cursor**。
*   **灵活配置**：
    *   **自定义路径**：为每个 Provider 配置使用的 Skills 目录。
    *   **安装方式**：选择 **软链接 (Symbolic Link)**（实时同步）或 **复制 (Copy)**（标准模式）进行安装。
*   **迁移助手**：自动检测 Provider 目录中的“孤立” Skills（物理文件），并帮助您将其迁移到 Nolon 的托管存储中。
*   **健康检查**：识别并修复损坏的软链接，保持环境健康。
*   **丰富的元数据支持**：解析标准 `SKILL.md` 的 frontmatter 以显示版本、描述和其他详细信息。
*   **完整文件夹支持**：将 Skills 作为完整文件夹管理，保留 `scripts/` 和 `references/` 等辅助文件。
*   **国际化**：完全支持 **英语** 和 **简体中文**。

## 🔄 Skills 管理工作流

1.  **导入**：将本地文件夹中的 Skills 导入到 Nolon 的全局存储中。
2.  **安装**：选择一个 Skill 并切换其在目标 Provider（如 Codex, Claude）中的安装状态。
3.  **迁移**：使用“按 Provider”视图查找现有的未托管 Skills，并将其迁移到 Nolon 的管理中。

## 🛠 项目结构

本项目遵循整洁架构（Clean Architecture）：

*   **Models**：领域实体（`Skill`, `SkillProvider` 等），位于 `Skills/Models`。
*   **Infrastructure**：存储和系统操作（`SkillRepository`, `SkillInstaller`），位于 `Skills/Infrastructure`。
*   **Views**：SwiftUI 用户界面（`SkillManagerView`, `SkillListView`），位于 `Skills/Views`。
*   **App**：入口点位于 `nolon/nolonApp.swift`。

## 🎨 设计系统

我们使用位于 `nolon/DesignSystem/AppColors.swift` 的代码化颜色系统。

**规则：**
*   **始终** 使用 `DesignSystem.Colors` 而不是硬编码的 `Color(...)` 或系统默认值。
*   **不要** 使用 `Color.blue`, `Color.white` 等。
*   **可用调色板**：
    *   **品牌**：`DesignSystem.Colors.primary`, `secondary`
    *   **背景**：`DesignSystem.Colors.Background.canvas`, `surface`, `elevated`
    *   **文本**：`DesignSystem.Colors.Text.primary`, `secondary`, `tertiary`, `quaternary`
    *   **状态**：`DesignSystem.Colors.Status.info`, `success`, `warning`, `error`
*   **暗黑模式**：所有颜色会自动适应系统外观。

## 💻 构建与运行

1.  在 Xcode 16+ 中打开 `nolon.xcodeproj`。
2.  等待 Swift Package Manager 解析依赖项 (MarkdownUI)。
3.  选择 **nolon** scheme 和 **My Mac** 作为目标。
4.  运行应用程序 (Cmd+R)。

### 命令行验证

您可以使用提供的辅助脚本验证构建：

```bash
./build.sh
```

或者使用 `xcodebuild` 手动构建：

```bash
xcodebuild -project nolon.xcodeproj -scheme nolon -configuration Release
```

## 📋 要求

*   macOS 15.0+
*   Xcode 16.0+ (用于构建)

## 🙏 致谢

本项目受到以下项目的启发并参考了它们：

*   **CodexSkillManager**: [https://github.com/Dimillian/CodexSkillManager](https://github.com/Dimillian/CodexSkillManager)
*   **SkillsManager**: [https://github.com/tddworks/SkillsManager](https://github.com/tddworks/SkillsManager)
