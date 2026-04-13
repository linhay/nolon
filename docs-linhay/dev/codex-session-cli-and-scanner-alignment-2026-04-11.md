# Codex Session CLI / Scanner / UI 对齐实现（2026-04-11）

## 背景
- `Sessions` 页已经具备手动 provider rewrite 能力，但 CLI 仍缺少等价命令面。
- `CodexSessionStore` 与 Codex 用量扫描各自维护一套 session 文件发现逻辑，重复遍历 `sessions/` / `archived_sessions/`，后续容易产生行为漂移。
- `CodexSessionsTabView` 仍保留页面内自绘卡片结构，没有对齐到 `NolonUIFoundation` + `NolonUI` 的共享分层。

## 本次设计

### 1. 公共扫描层
- 新增 `libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift`
- 责任：
  - 扫描 `sessions/` 与 `archived_sessions/`
  - 同时支持日期分区目录与平铺 jsonl
  - 产出稳定 `relativePath`、`archived`、`fileIdentity`
  - 读取轻量 session meta：`threadID`、`modelProvider`、`cwd`、`updatedAt`
- 结果：
  - `CodexSessionStore` 保留 session 聚合与 rewrite 责任
  - `CostUsageScanner` 保留 tokens/cost 聚合责任
  - 两者共享同一文件发现与 provider 归一化语义

### 2. CLI 命令面对齐 UI
- 新增 `nolon codex session` group，子命令：
  - `list`
  - `preview-rewrite`
  - `rewrite`
- `list` 新增 `--group-by provider|time-project`，与 UI `Sessions` 页的分组切换保持一致。
- CLI payload 改为纯视图模型，不直接暴露 provider 层的非 `Codable` 结构：
  - `NolonCodexSessionRewritePreviewView`
  - `NolonCodexSessionRewriteResultView`
- 选择源建模为：
  - `threadIDs([String])`
  - `modelProvider(String)`
- `preview-rewrite` / `rewrite` 的解析、help、文本输出与 UI 确认语义保持一致。
- `list` 的文本输出新增 `group_by` 字段；`time-project` 模式下 section 标题显示 `日期 · 项目名`，row 文本补充 provider。

### 3. UI 共享分层
- `libs/NolonUIFoundation` 新增 Sessions 数据模型：
  - `CodexSessionsOverviewData`
  - `CodexSessionsSectionData`
  - `CodexSessionsRowData`
  - `CodexSessionsLoadMoreData`
- `libs/NolonUI` 新增共享组件：
  - `CodexSessionsOverviewCardView`
  - `CodexSessionsSectionCardView`
  - `CodexSessionsLoadMoreButton`
- `CodexSessionsTabView` 只做状态绑定与 action 转发，不再承载会话卡片的布局细节。

### 4. 分组切换语义
- `Sessions` 页新增两种分组模式：
  - `provider`
  - `time_project`
- `provider` 模式下延续原有行为：
  - section 按 `model_provider` 聚合
  - 支持 section 级 `Move Group`
- `time_project` 模式下：
  - section key 为 `yyyy-MM-dd + normalized cwd`
  - section 标题显示为 `日期 · 项目名`
  - row 级补充 provider badge，避免合组后来源丢失
  - 若 section 内包含多个 provider，则禁用 section 级 rewrite，仅保留单条 session rewrite

## 影响文件
- Provider：
  - `libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift`
  - `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift`
  - `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift`
- CLI：
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCommands.swift`
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLIPayloads.swift`
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift`
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLIExecutor.swift`
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLIHelp.swift`
- UI：
  - `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift`
  - `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`

## 测试策略
- Provider：
  - 新增 `CodexSessionScannerTests`
  - 更新 `CodexSessionStoreTests`
- CLI：
  - 更新 `NolonCodexCLIEntrypointTests`
  - 新增 session help / route 覆盖
- App：
  - 保持 `CodexSessionsTabViewModelTests`
  - 保持 `CodexSessionsTabConfigurationTests`

## 风险结论
- `Providers-Package` 的 test action 会编译整个 `ProvidersTests` target，不只执行指定用例，因此局部改动也会暴露其他测试文件的编译问题。
- CLI payload 必须维持“纯可编码视图模型”边界；否则一旦 provider 内部模型不是 `Codable`，`--json` 输出会再次在模块编译阶段失败。
