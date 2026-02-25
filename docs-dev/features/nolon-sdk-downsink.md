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

## 迁移收口进展（2026-02-25）
1. 新增 `CodexModelPreferenceService`（SDK）：
   - 统一 `config.toml` 读取：`model`、`model_reasoning_effort`。
   - 统一 `models_cache.json` 读取与可见模型合并（provider cache + `~/.codex` fallback）。
   - 统一模型保存/清空入口（封装 `CodexBinaryManager.applyModelToConfig/clearPreferredModel`）。
2. App 去重并切换到 SDK：
   - `ProviderDetailGridViewModel` 删除本地重复 `CodexMCPConfig/CodexProject/CodexNotice/CodexMCPServer` 定义，改用 SDK 模型。
   - `ProviderDetailGridViewModel` 的模型读取/保存逻辑改走 `CodexModelPreferenceService`。
   - `CodexAdvancedConfigViewModel` 改用 `CodexModelPreferenceService` 加载缓存与配置，不再本地手写解析 `config.toml`。
3. 远端刷新策略下沉：
   - 新增 `RemoteRefreshPolicy`（SDK），抽离安装后刷新与目录选择展示延迟常量。
   - App 中 `RemoteSkillsBrowserView` / `RemoteRepositorySidebarView` 替换硬编码 `0.5s`。
4. 验证结果：
   - `swift test --package-path libs/Providers --filter NolonResourceKitTests` 通过（新增服务测试）。
   - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过。
   - `./build.sh` 通过。

## 迁移收口进展（2026-02-25 / 一次性收口）
1. Remote 查询能力下沉（SDK）：
   - 新增 `RemoteCatalogQueryService`，统一 Clawdhub / GlobalCache / LocalFolder / Git 四类仓库的 skills/workflows/mcps 查询入口。
   - 新增 `RemoteRepositoryCountService`，统一 Tab 计数口径。
2. 仓库同步编排下沉（SDK）：
   - 新增 `RepositorySyncOrchestrator`，统一 Git 同步结果、目录候选、是否弹目录选择的判定逻辑。
3. Provider 资源快照下沉（SDK）：
   - 新增 `ProviderResourceSnapshotService`，聚合 workflows/rules/agents/mcps 与 MCP cache state。
4. 状态模型统一桥接（SDK + CLI）：
   - 新增 `ResourceHealthState`。
   - `ProviderSkillStateKind`、`ProviderResourceState`、`NolonProviderSkillStateKind` 增加与 `ResourceHealthState` 的互转。
5. App 同步：
   - `RemoteContentTabViewModel` 使用 `RemoteRepositoryCountService`。
   - `RemoteSkillsGridViewModel` 使用 `RemoteCatalogQueryService`（含分页与 canLoadMore 逻辑）。
   - `AddRepositoryViewModel`、`RemoteRepositorySidebarViewModel` 使用 `RepositorySyncOrchestrator`。
   - `ProviderDetailGridViewModel` 使用 `ProviderResourceSnapshotService`。
6. CLI 同步：
   - `NolonLiveSkillsRepositoryService.listRemoteResources` 改走 `RemoteCatalogQueryService`，与 app 共用同一查询策略与数据源路由。

## 迁移收口进展（2026-02-25 / 一次性收口·第二批）
1. 资源视图映射下沉（SDK）：
   - 新增 `ProviderResourceViewMapper`，统一将 `ProviderResourceItem` 映射为 workflow/rule/agent 的 UI 视图数据。
   - App `ProviderDetailGridViewModel` 改为通过 `ProviderResourceSnapshotService + ProviderResourceViewMapper` 产出三类视图数据，删除本地重复扫描/解析分支。
2. 仓库草稿与校验下沉（SDK）：
   - 新增 `RepositoryDraftService`（默认模板、导入 URL 解析、重复校验）。
   - App `AddRepositoryViewModel` 的 `pendingImportURL` 处理、名称自动推断、重复校验全部改走 SDK。
3. 远端分页缓存下沉（SDK）：
   - 新增 `RemoteCatalogPagingStore`，统一缓存键、分页上限、cache-buster 判定、错误缓存。
   - App `RemoteSkillsGridViewModel` 改为使用该 store 管理分页状态与缓存命中。
4. Usage 聚合策略下沉（SDK）：
   - 新增 `ProviderUsageSnapshotService`，统一 usage outcome 的成功/失败/credits/latest 聚合口径。
   - App `ProviderUsageViewModel` 接入该聚合服务并暴露 `usageAggregate`。
5. CLI 文本渲染同步（SDK -> CLI）：
   - 新增 `RemoteSearchTextPresenter`（workflow/mcp 搜索文本渲染）。
   - CLI `NolonCoreCLIRunner.formatResourceSearchText` 改为调用该 presenter，仅保留数据映射。
6. 测试与验证：
   - 新增 SDK 测试覆盖：`ProviderResourceViewMapper`、`RepositoryDraftService`、`RemoteCatalogPagingStore`、`ProviderUsageSnapshotService`、`RemoteSearchTextPresenter`。
   - `swift test --package-path libs/Providers --filter NolonResourceKitTests` 通过（40 tests）。
   - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（189 tests）。
   - `./build.sh` 通过。
