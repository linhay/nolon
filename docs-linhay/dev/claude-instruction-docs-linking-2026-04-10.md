# Claude Code 指令文档接入说明

## 目标
- 在不破坏现有 `AGENTS.md` 管理体系的前提下，让 Claude Code provider 也能进入 `Agents` tab 管理。

## 本次决策
- Claude provider 的厂商原生指令文件路径使用 `~/.claude/CLAUDE.md`。
- Claude provider 在 Nolon 中显示 `Agents` tab，并按真实文件名 `CLAUDE.md` 展示、编辑、删除、新建。
- Claude provider 的 link 模式不新增 `~/.nolon/agents/CLAUDE.md`。
- Claude provider 开启 link 后，`~/.claude/CLAUDE.md` 会被符号链接到 `~/.nolon/agents/AGENTS.md`。

## 这样做的原因
- 保持现有体系的单一事实源仍然是 `AGENTS.md`，避免 Nolon 全局页再维护一套 `CLAUDE.md` 主源。
- Claude Code 读取的是文件名 `CLAUDE.md`；符号链接目标使用 `AGENTS.md` 不影响 Claude 侧读取。
- 现阶段不引入 `CLAUDE.override.md`，避免发明 Claude 官方没有承诺支持的覆盖语义。

## 代码影响
- `ProviderTemplateEmbeddedJSON`
  - Claude template 新增 `agents` vendor tab。
- `Provider+ClaudePaths`
  - 统一定义 `claudeHomeFolder` / `claudeInstructionsFile` / `claudeInstructionsFileURL`。
- `ProviderResourceService`
  - Claude provider 的 agent doc 扫描目标改为 `CLAUDE.md`。
- `ProviderAgentsLinkService`
  - Claude provider 的 link 目标为 `~/.nolon/agents/AGENTS.md`。
- `ProviderResourceMonitor`
  - 监听 `~/.claude/CLAUDE.md`，link 模式下额外监听 `~/.nolon/agents/`。

## 验证口径
- app 侧定向测试通过：
  - `GeminiUsageTabConfigurationTests`
  - `CodexAgentsTabTests`
  - `ProviderAgentsLinkServiceTests`
  - `ProviderDetailGridViewIssueNavigationTests`
  - `MainSplitViewModelTests/testBDD_GivenUITestLaunchSelectionForClaudeAgents_WhenResolved_ThenAgentsTabIsApplied`
- Providers package 的新增路径测试未单独跑通，阻塞于仓库现有 `swift-collections` 编译错误，不是本次改动引入。
