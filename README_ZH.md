# Nolon

[English](README.md) | 中文

Nolon 是一个面向 AI 编程助手的 macOS 控制中枢。  
它把 **Skills**、**Provider 配置**、**MCP 配置** 放在同一套管理模型里，统一编排到 **Codex**、**Claude Code**、**Cursor** 等 20+ 工具。

Nolon 不把 Skill 仅当作“文件管理”，而是把整套环境当作可运维系统：
*   统一事实源：`~/.nolon/skills`
*   可预测安装：按 Provider 执行软链接或复制
*   远程分发 + 本地生命周期：导入、迁移、修复、更新
*   双更新链路：应用更新（Sparkle）+ 内容更新（Skills/MCP）

## 📦 下载

*   **最新版本**：[v1.3.5](https://github.com/linhay/nolon/releases/latest)
*   **Appcast（Sparkle 更新源）**：[appcast.xml](https://linhay.github.io/nolon/appcast.xml)

## 🚀 主要功能

### 1) Provider 集群管理
*   **广泛 Provider 支持** (25+)：
    *   **Codex**, **Claude Code**, **OpenCode**, **GitHub Copilot**, **Gemini CLI**, **Antigravity**, **Cursor**, **Amp**, **Clawdbot**, **Cline**, **Command Code**, **Droid**, **Goose**, **Kilo**, **Kiro**, **MCPJam**, **OpenHands**, **Pi**, **Qoder**, **Qwen**, **Roo**, **Trae**, **Windsurf**, **Zencoder**, **Neovate**。
*   **按 Provider 配置目录**：每个 Provider 可独立指定目标路径。
*   **按 Provider 设定安装策略**：**软链接**（实时）或**复制**（快照）。

### 2) Skills 生命周期编排
*   **中心化仓库**：`~/.nolon/skills` 作为单一事实来源。
*   **统一导入/安装/卸载**：在一个界面内管理多 Provider 分发。
*   **迁移助手**：自动识别 Provider 目录下的孤立/手工 Skill 并纳管。
*   **健康检查与修复**：识别并修复软链接损坏与状态漂移。
*   **元数据解析**：支持 `SKILL.md` frontmatter。
*   **完整目录技能模型**：保留 `scripts/`、`references/` 等配套资源。

### 3) 远程分发与 MCP
*   **Clawdhub 集成**：浏览并一键安装远程 Skills。
*   **远程仓库能力**：支持仓库源同步工作流。
*   **MCP 管理**：按 Provider 管理 MCP 配置并支持远程 MCP 安装流程。

### 4) 运维与更新
*   **内容更新检查**：检查已管理 Skills 的可用更新。
*   **应用自更新**：通过 Sparkle 分发 Nolon 新版本。
*   **国际化**：支持英文与简体中文界面。

## 🔄 工作流

### 本地生命周期
1.  **导入**：将本地文件夹中的 Skills 导入到 Nolon 的全局存储中。
2.  **安装**：选择一个 Skill 并切换其在目标 Provider（如 Codex, Claude）中的安装状态。
3.  **迁移**：使用"按 Provider"视图查找现有的未托管 Skills，并将其迁移到 Nolon 的管理中。
4.  **修复**：通过健康检查识别并修复损坏链接和状态不一致。

### 远程生命周期
1.  **浏览**：打开远程浏览器（Clawdhub 或已配置仓库源）。
2.  **检索**：按名称或更新时间查找 Skills / MCP。
3.  **安装**：选择目标 Provider 与安装策略。
4.  **同步**：将远程变更同步到本地事实源，再应用到各 Provider。

## 🛠 项目结构

本项目遵循整洁架构（Clean Architecture）：

*   **Models**：领域实体（`Skill`, `Provider`, `RemoteSkill` 等），位于 `Skills/Models`。
*   **Infrastructure**：存储和系统操作（`SkillRepository`, `SkillInstaller`, `ClawdhubService`），位于 `Skills/Infrastructure`。
*   **Views**：SwiftUI 用户界面（`MainSplitView`, `RemoteSkillsBrowserView`），位于 `Skills/Views`。
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

### Git 子模块

本仓库在 `libs/` 下使用 git submodule。构建前请先拉取子模块：

```bash
git submodule update --init --recursive
```

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
*   **Clawdhub**: [https://clawdhub.com](https://clawdhub.com) - 远程 Skills 仓库
