# 争论背景

当前问题是：用户在 Nolon 内编辑一个已经激活的 Codex configured account 后，`config.toml` 会更新，但 provider 目录下实际给 CLI 使用的 `auth.json` 没有同步变化。

需要回答的不是“现象是否存在”，而是：

1. 这是预期行为还是实现缺口。
2. 真正的 source of truth 是谁。
3. 最小修复点应该落在哪个同步阶段。

# 参与者观点

## 第 1 轮

### TraceForge：SQLite 才是真源，`auth.json` 只是激活物化层

- `updateConfiguredAccount(...)` 会把编辑结果写回 SQLite snapshot。
- `accountAuthData(for:)` 以及 UI reload 后看到的新配置，都是从 SQLite 读出来的。
- `materializeManagedActiveAuthFile(...)` 只在激活链路里把最新 snapshot 物化到 `active-auth/<provider>/auth.json`。

结论：

- 编辑后 UI 看起来“已经更新”，并不代表 provider `auth.json` 已经更新。
- 因为 UI 读的是 SQLite，不是 provider 目录下的实际运行时文件。

### StateSmith：当前编辑链路只刷新 `config.toml`，不会重建 active `auth.json`

实际调用链：

1. `ProviderUsageEngine+CodexManagement.swift`
   - `updateConfiguredAccount(...)`
   - `refreshActiveProviderConfigIfNeeded(...)`
2. `refreshActiveProviderConfigIfNeeded(...)`
   - 只会调用 `syncActiveProviderConfig(...)`
3. `syncActiveProviderConfig(...)`
   - 只 patch / restore `config.toml`
   - 不会调用 `materializeManagedActiveAuthFile(...)`
   - 也不会重建 provider auth symlink

结论：

- 当前编辑 active configured account 后，`config.toml` 与 SQLite 能变，但 active `auth.json` 不会自动同步。

## 第 2 轮

### TestLens：现有测试只覆盖 `config.toml`，没覆盖 provider `auth.json`

已有测试覆盖了：

- relay active account 更新后 `config.toml` 会改
- 历史 rollout / state db 的 `model_provider` 会迁移

但缺少一条关键断言：

- 编辑 active configured account 后，`readAuthJSONString(from: provider)` 必须体现新的 API key / relay metadata

因此：

- 这不是“代码没问题，只是观察口径不同”
- 而是测试没有把运行时文件同步这层行为锁住

### Gemini CLI：这是 bug，不是纯预期

Gemini CLI 的判断是：

- `updateConfiguredAccount(...)` 只改 SQLite
- `refreshActiveProviderConfigIfNeeded(...)` 只改 `config.toml`
- active `auth.json` 仍然保留激活当时那一版 payload

因此：

- 对当前 active account 进行编辑后，CLI 实际读取的 `auth.json` 仍可能是旧值
- 这是会影响实际运行结果的 bug

## 第 3 轮

### 内部收口：最小修复点应落在 `refreshActiveProviderConfigIfNeeded(...)`

为什么不把修复放在更上层 UI：

- UI 只是一个调用者
- 真正的语义是“当 active account 被刷新配置时，provider 运行时文件必须同步”

为什么不改 `updateConfiguredAccount(...)`：

- 它本身不知道当前 provider 上下文
- 也不知道当前 account 是否正处于 active 状态

因此最小修复点收敛为：

- 在 `refreshActiveProviderConfigIfNeeded(...)` 内
- 当确认该 account 就是 active account 时
- 在 auth lock 中，先同步 `config.toml`
- 再重新 materialize active `auth.json`

# 结论与行动项

## 最终结论

1. `auth.json` 没更新不是单纯“预期如此”，而是 active configured account 编辑场景下的实现缺口。
2. 当前 source of truth 是 SQLite snapshot。
3. provider 目录下的 `auth.json` 是激活阶段物化出来的运行时视图，不会因为 SQLite 更新而自动重建。
4. 当前缺口的直接原因是：
   - 编辑链路只走了 `updateConfiguredAccount(...) + refreshActiveProviderConfigIfNeeded(...)`
   - 但后者只同步 `config.toml`，没有重新物化 active `auth.json`

## 最小修复

在 `refreshActiveProviderConfigIfNeeded(...)` 中补一条 active auth 物化：

1. 先执行 `syncActiveProviderConfig(...)`
2. 再执行 `activateAccount(account, for: provider)`

这样可以保证：

- `config.toml` 仍按现有状态机更新
- provider `auth.json` 会同步到最新 SQLite payload
- symlink 若缺失或漂移，也会被一并修正

## 最小验证集

1. Given active relay configured account 已激活
   When 编辑 API key / relay metadata 并调用 `refreshActiveProviderConfigIfNeeded(...)`
   Then provider `auth.json` 必须体现最新 payload

2. Given active relay configured account 已激活
   When 编辑 relay metadata 并调用刷新
   Then `config.toml` 仍继续按现有逻辑重写

3. Given relay active 后再切回 oauth
   When 账号切换
   Then 既有 patch / restore 语义不能回归
