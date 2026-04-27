# Codex `config.toml` 单一读写收拢实现

## 背景
- `config.toml` 被多个模块分别读写：
  - `CodexBinaryManager`
  - `MCPConfigManager`
  - `CodexActiveProviderConfigManager`
  - `NolonCodexCLI.prepareIsolatedLoginHome`
  - 高级配置 UI 保存逻辑
- 问题不只是“谁都能写”，更是“谁都在本地读旧快照后再整文件写回”，容易丢掉其他模块刚写入的内容。

## 实现
- 新增 `CodexConfigStore`：
  - 以 `config.toml` 绝对路径为粒度建立进程内锁。
  - 以同路径 `.lock` 文件建立跨进程 advisory lock，避免仓外或子进程绕过进程内锁时发生交错写。
  - 所有变更通过 `update(_:)` 串行执行，统一 read-modify-write。
  - 落盘改为原子写，避免半写入态暴露给并发读者。
  - 提供通用顶层字符串键 patch：`setTopLevelStringValue` / `removeTopLevelValue`。
  - 提供共享读取能力：typed raw read、`model_provider` / `[model_providers.*]` 解析。
- 下游迁移：
  - `CodexBinaryManager` 不再自己字符串替换顶层键。
  - `MCPConfigManager` 写 TOML 时改为通过 store 更新 `[mcp_servers]` 片段。
  - `CodexActiveProviderConfigManager` 的 relay apply / restore 改为通过 store 落盘。
  - `NolonCodexCLI.prepareIsolatedLoginHome` 不再覆盖整份文件，只修 `cli_auth_credentials_store`。
  - `ProviderUsageEngine.prepareCLILoginHomeDirectory` 的 app 内登录 home 预处理也改为只修 `cli_auth_credentials_store`。
  - 高级配置 UI 保存改为基于 store 执行 patch。
  - `CodexConfigEditorView` 的全文编辑保存改为通过 store 落盘，共享同一路径锁和原子写。

## 结果
- 统一了 `config.toml` 的核心写入口。
- 消除了主要写路径上的“直接整文件覆盖”。
- 补齐了“同仓多入口”之外的第二层防线：
  - 同一台机器上的其他进程如果也按 `.lock` 文件协议访问同一路径，会与当前写路径互斥。
  - 原子写降低了配置文件被读到中间态或写坏的风险。
- 新增回归测试覆盖：
  - 并发非重叠更新不会互相覆盖。
  - 外部进程持锁时，store 更新会等待释放后再写入。
  - 登录预处理只更新受控键，不抹掉其他 section。
  - app 内 `ProviderUsageEngine` 登录 home 预处理同样只更新受控键，不覆盖已有 section。

## 未做
- 没有把所有只读解析都完全收口；当前优先解决“配置丢失”的写路径问题。
- 没有做强制性的系统级文件锁兼容层：
  - 当前采用 advisory lock，前提是参与方都遵守同一锁文件协议。
- 没有新增 repo 级 `skills` 或调整 `AGENTS.md`：
  - 这次是一次性实现收敛，还不足以沉淀成稳定、重复出现的项目级操作模板。
