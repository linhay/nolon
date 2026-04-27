# Codex API Key / OAuth `config.toml` 联动设计

## 背景
- 问题：Codex API key 模式下，`auth.json` 已切换到目标账号，但 `config.toml` 没有同步，导致自定义 relay provider 仍未生效。
- 官方约束：自定义 provider 需要通过 `config.toml` 指定顶层 `model_provider`，并提供对应的 `[model_providers.<id>]` 配置块；仅写 `auth.json` 不足以驱动自定义 provider。
- 上游参考：
  - OpenAI Codex config reference
  - `codex-rs/core/src/model_provider_info.rs`
  - `codex-rs/app-server/src/codex_message_processor.rs`

## 本次修改范围

### 代码链路
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift`
  - 在 `activateAccountAndMarkActive(...)` 中，账号激活后同步 `config.toml`
  - 在 `preflightManagedAuthIfNeeded(...)` 中，自愈/迁移后同步 `config.toml`
  - 在 `reconcileDetachedProviderAuthIfNeeded(...)` 中，provider auth 脱链修复后同步 `config.toml`
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexManagement.swift`
  - 编辑 API key 账号后，如果该账号当前处于激活态，立即刷新 `config.toml`

### 新增组件
- `libs/Providers/Sources/ProviderUsage/CodexActiveProviderConfigManager.swift`
  - 负责对 `config.toml` 做文本级 patch / restore
  - 单独保存“接管前原始内容”，确保 relay -> OAuth / 官方 API key 切换时可恢复
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager+ActiveProviderConfig.swift`
  - 负责识别当前账号属于：
    - relay API key：写入托管配置
    - OAuth / 官方 API key：恢复原配置
    - gateway 虚拟账号：跳过，不干预 gateway 自己的 patch

### 关联修复
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SnapshotHelpers.swift`
  - 配置账号 payload 生成时，同步维护顶层 `base_url`
  - 目的：避免编辑当前激活 relay 账号后，SQLite 重建 auth 数据时仍读到旧 `base_url`

## 新增根因确认
- 这次问题不只是“激活后没有 patch `config.toml`”。
- 排查确认还有一个更早发生的数据污染：
  - API key relay 账号表单里的 `Model Provider` 候选，错误地来自 `models_cache.json`
  - `models_cache.json` 提供的是模型 slug，例如 `gpt-5.4`
  - relay 真正需要保存的是 provider id，例如 `provider-relay`
- 结果：
  - 新建 relay 账号时，`nolon.relay.model_provider` 可能被错误保存成模型名
  - 后续 `config.toml` patch 虽然执行，但会基于错误的 provider id 写出 section
  - 这会导致顶层 `model_provider`、`[model_providers.<id>]`、账号快照三者不一致

## 本轮补丁
- `libs/Providers/Sources/NolonResourceKit/Infrastructure/CodexModelPreferenceService.swift`
  - 新增 `loadRelayModelProviderIDs(for:)`
  - relay provider 候选改为从当前 `config.toml` 读取：
    - 顶层 `model_provider`
    - `[model_providers.<id>]` section 名
  - 不再把 `models_cache.json` 当作 relay provider 建议来源
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexManagement.swift`
  - Relay 表单建议项改为读取 `config.toml`
  - `saveCodexConfigEditor()` 新增 `modelProvider` 必填校验
  - `validateCodexConnectionDraft()` 新增 `modelProvider` 必填校验
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SnapshotHelpers.swift`
  - relay payload 新增 `baseURL` / `modelProvider` 非空校验
  - 防止 UI 漏校验时继续写出坏快照
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexAuxSharedViews.swift`
  - 提示文案从 `Suggested from models cache` 改为 `Suggested from current config`

## 用户可见现象解释
- 当当前激活的是一个已被错误保存的 relay 账号时，Codex CLI / app-server 读取错误 provider 配置后，可能直接异常退出。
- 用户侧会表现为：
  - `Codex protocol error: transport: JSON-RPC process terminated`
- 刷新后偶尔恢复，不代表问题消失；更常见是命中了残留的旧配置或回退状态。

## 历史会话不可见的根因
- 仅修 `config.toml` patch 还不够。
- 上游 Codex 在恢复历史会话时，会默认按当前 `model_provider` 过滤：
  - app-server `list_threads` 默认取当前 provider
  - TUI resume picker 只查当前 provider
  - `codex resume --last` 也只看当前 provider
- 过滤来源有两层：
  - rollout 文件头部 `session_meta.payload.model_provider`
  - `state_4.sqlite` 中 `threads.model_provider`
- 所以当 Nolon 把当前 provider 从 `openai` 切成 relay provider 后，旧的 `openai` 历史并没有丢，只是被当前 provider 过滤掉了。

## 现存坏数据处理
- 修复后，新建 relay API key 账号会保存正确的 provider id，并写出一致的 `config.toml`。
- 兼容修复后，如果旧 relay 账号缺少 `nolon.relay.model_provider`，但当前 `config.toml` 已存在可唯一匹配同一 `base_url` 的 provider section：
  - 激活时会从当前 `config.toml` 推断 provider id
  - 同时回写账号快照，补上 `nolon.relay.model_provider`
- 仍然无法自动修复的情况：
  - 旧账号被错误保存成“模型名”而不是 provider id
  - 当前 `config.toml` 中同一 `base_url` 对应多个 provider section，无法唯一判定
- 上述无法唯一判定的旧账号，仍需重新编辑并保存一次，或直接重建。

## 历史会话兼容迁移

### 新增组件
- `libs/Providers/Sources/ProviderUsage/CodexSessionProviderMigrationManager.swift`
  - 在切换当前激活 provider 时，同步迁移 Codex 历史线程的 provider 元数据
  - 覆盖：
    - `sessions/**/*.jsonl`
    - `archived_sessions/**/*.jsonl`
    - `state_*.sqlite` 的 `threads.model_provider`

### 迁移规则
- OAuth / 官方 provider -> relay provider
  - 把“基础 provider”下的历史线程迁移到当前 relay provider
  - 如果之前已由另一个 relay provider 接管，也会把旧 relay provider 一并迁移到新 relay provider
- relay provider -> OAuth / 官方 provider
  - 把上一次托管的 relay provider 历史迁回基础 provider
- relay provider id 变更
  - 例如 `provider-one` -> `provider-two`
  - 会同步迁移 rollout / state db 中的历史 provider 元数据，避免切换后 resume 列表再次空掉

### 基础 provider 判定
- 优先读取 relay 接管前原始 `config.toml` 的顶层 `model_provider`
- 若原配置未显式声明，则回退为 `openai`

## `config.toml` 托管字段范围

### relay API key 激活时强制写入的顶层字段
```toml
model = "gpt-5.4"
model_reasoning_effort = "xhigh"
model_provider = "<sanitized-provider-id>"
```

### relay API key 激活时写入的 provider section
```toml
[model_providers.<sanitized-provider-id>]
name = "<sanitized-provider-id>"
base_url = "https://relay.example.com/v1"
query_params = { "k" = "v" }      # 可选
http_headers = { "k" = "v" }      # 可选
requires_openai_auth = true
wire_api = "responses"
```

### 切换规则
- relay API key -> OAuth：恢复 relay 接管前原始 `config.toml`
- relay API key -> 官方 API key（无 `nolon.relay`）：恢复 relay 接管前原始 `config.toml`
- OAuth / 官方 API key -> relay API key：重新写入 relay provider 配置
- gateway 虚拟账号激活：跳过，不修改 `config.toml`

## provider id 规范化
- 写入 `config.toml` 前统一做：
  - 转小写
  - 非 `[a-z0-9_-]` 字符替换为 `-`
  - 连续 `-` 折叠
  - 去掉首尾 `-`

## 脱敏示例
```toml
model = "gpt-5.4"
model_reasoning_effort = "xhigh"
model_provider = "provider-relay"

[model_providers.provider-relay]
name = "provider-relay"
base_url = "https://relay.example.com/v1"
requires_openai_auth = true
wire_api = "responses"
```

## 验证
- 已通过：
  - `xcodebuild build -project nolon.xcodeproj -scheme NolonResourceKit -destination 'platform=macOS'`
  - `xcodebuild build -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS'`
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageEngineValidateConfiguredAccountTests`
    - 6 个用例全部通过
    - 覆盖：
      - relay provider 候选从 `config.toml` 读取
      - 编辑态保留当前 provider
      - relay 草稿缺少 `modelProvider` 时 UI 直接报错
      - 历史 relay 坏快照在激活时借助当前 `config.toml` 自动补回 `model_provider`
- 未直接通过：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:ProvidersTests/...`
  - 原因：`ProvidersTests` 当前不在 `nolon-tests` scheme / test plan 中，无法通过主工程 scheme 定向执行
  - `swift test --package-path libs/Providers --filter CodexConfiguredAccountTests`
  - 原因：被仓库现有第三方依赖基线问题阻塞，不是本次改动引入：
    - `libs/Providers/.build/checkouts/swift-collections/Sources/ContainersPreview/Extensions/TemporaryAllocation.swift`
    - 报错：`thrown expression type 'any Error' cannot be converted to error type 'E'`

## 增量（2026-04-10：Sessions tab 手动修正入口）
- 关联规格：
  - [codex-sessions-tab-2026-04-10.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/spaces/codex-sessions-tab/README.md)
- 目的：
  - 在自动迁移之外，为 Codex / CodexXcode 提供可视化、可确认的历史会话 provider 重写入口。
- UI 接线：
  - `ProviderContentTabView` 为 `codex` / `codexXcode` 注入 `Sessions` tab。
  - `ProviderDetailGridView` 接入 `CodexSessionsTabView`。
- SDK / 数据层：
  - `CodexSessionStore` 新增 `previewRewrite` / `rewriteProviders`，直接改写 rollout + `state_*.sqlite`。
  - `CodexSessionProviderMigrationManager` 改为复用 `CodexSessionStore.migrateProviders(...)`，避免 UI 手动修正与激活态自动迁移使用两套规则。
- 验证补充：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabConfigurationTests -only-testing:nolonTests/CodexSessionsTabViewModelTests -only-testing:nolonTests/CodexRuntimeTabConfigurationTests`
  - `swift test --package-path libs/Providers --filter CodexSessionStoreTests`
  - `swift test --package-path libs/Providers --filter relayActivationMigratesHistoryProviderMetadataAndOAuthRestoresIt`
  - `swift test --package-path libs/Providers --filter refreshActiveRelayConfigMigratesHistoricalProviderMetadata`
