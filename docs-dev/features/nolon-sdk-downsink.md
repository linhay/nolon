# Nolon App 能力下沉 SDK（NolonResourceKit）

## 背景
- 现有 App 在 `nolon/Skills` 中实现了大量技能/工作流/MCP/远程仓库/缓存等能力，CLI 侧难以复用。
- 目标是把 App 的资源能力下沉到 `libs/Providers` SDK，使 CLI 与 App 共享能力与行为。

## 目标
1. 将资源相关领域模型与基础设施下沉到 SDK（`NolonResourceKit`）。
2. App 仅做 UI 编排与调用 SDK，不再持有重复实现。
3. 统一 `NOLON_HOME` 解析逻辑，SDK 与 CLI/App 使用同一套目录布局。

## 非目标
- UI 视图与交互逻辑（SwiftUI）不下沉。
- App 视觉与本地化策略不变。

## BDD 验收场景
### 场景 1：SDK 暴露资源能力
**Given** App 需要安装/扫描技能、管理 MCP/Workflow、访问远程仓库
**When** App 引入 `NolonResourceKit`
**Then** App 只调用 SDK 中的 `SkillRepository/SkillInstaller/ResourceInstaller/...` 等能力，不再依赖 App 内部副本实现

### 场景 2：NOLON_HOME 一致性
**Given** 环境变量 `NOLON_HOME=/tmp/nolon-test`
**When** App/CLI 初始化 `NolonManager`
**Then** 资源根目录与缓存目录应指向 `/tmp/nolon-test` 下的标准结构

### 场景 3：CLI 与 App 共享模型
**Given** 远程资源模型 `RemoteSkill/RemoteWorkflow/RemoteMCP/RemoteRepository`
**When** CLI 或 App 调用 SDK 返回这些模型
**Then** 两侧使用相同结构与字段语义

## 测试策略
- SDK 单测覆盖 NolonManager 对 `NOLON_HOME` 的解析。
- 逐步补齐资源安装/缓存行为的单元测试与 JSON 契约测试。

## 迁移收口进展（2026-02-16）
1. 修复 App target 缺失 `NolonResourceKit` 包依赖问题：将 `NolonResourceKit` 加入 `nolon` target 的 package product dependencies 与 frameworks。
2. 修复 CLI 可执行入口冲突：`libs/Providers/Sources/NolonCLI/main.swift` 重命名为 `NolonCLIApp.swift`，保留 `@main`，避免与 `main.swift` 顶层入口规则冲突。
3. 修复 SDK 暴露层可见性：
   - `String.nonEmpty` 调整为 `public`。
   - `STPathProtocol.deleteIncludingBrokenSymlink()` 调整为 `public`。
   - `Provider.codexRulesURL/codexAgentsFileURL/...` 调整为 `public`。
   - `UsageMonitorFileWatcher.watchedPathsForTesting` 调整为 `public`。
4. 修复 App 侧迁移遗漏导入：补齐多处 `import NolonResourceKit`，使 `Skill`、`ProviderSkillState`、`FrontmatterParser` 与扩展 API 可见。
5. 回归结果：
   - `./build.sh` 通过。
   - `swift test --package-path libs/Providers --filter NolonResourceKitTests` 通过。
   - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过。
   - `swift test --package-path libs/Providers --filter CodexAuthManagerTests` 通过。
