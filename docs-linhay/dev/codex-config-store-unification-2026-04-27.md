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
  - 切账号 restore 不再整份回滚 relay 激活时记录的旧快照；relay 激活后由 app 内其他模块新增的 MCP / 其他无关配置会被保留。

## 未做
- 没有把所有只读解析都完全收口；当前优先解决“配置丢失”的写路径问题。
- 没有做强制性的系统级文件锁兼容层：
  - 当前采用 advisory lock，前提是参与方都遵守同一锁文件协议。
- 没有新增 repo 级 `skills` 或调整 `AGENTS.md`：
  - 这次是一次性实现收敛，还不足以沉淀成稳定、重复出现的项目级操作模板。

## 额外根因修正
- 仅靠单一写入口还不够，`CodexActiveProviderConfigManager.restoreManagedConfig` 原先仍会把 `originalRawConfig` 整份写回。
- 这会导致一个纯 app 内即可复现的问题：
  1. 激活 relay 账号，记录 baseline 到 `originalRawConfig`
  2. app 内其他功能继续写入 `config.toml`（例如 MCP section）
  3. 切回 oauth / 非 relay 账号
  4. restore 直接回放旧 baseline，把第 2 步新增项一起覆盖掉
- 当前已改为：
  - 以当前 `config.toml` 为主
  - 只移除 managed relay 顶层键和 `[model_providers.<managed>]`
  - 再把 baseline 中受控顶层键补回
  - 从而保留 relay 激活后 app 内新增的无关配置

## MCP 标准化副作用修正
- 用户反馈 Codex MCP 配置会被我们“标准化”后失效，根因有两层：
  - 启动期 `repairProviderMCPStateIfNeeded(for:)` 会被动重写 Codex provider 原始 `config.toml`
  - `CodexMCPServer` / `MCPConfigManager` 先前未覆盖全部官方 MCP 字段，导致一旦进入读写链路，以下官方字段会被吃掉：
    - `supports_parallel_tool_calls`
    - `default_tools_approval_mode`
    - `experimental_environment`
    - `[mcp_servers.<server>.tools.<tool>] approval_mode`
- 已修正：
  - 对 `codex` / `codexXcode`，启动 repair 只修 cache，不再被动改 provider 原文件
  - 扩展 Codex MCP 模型和 TOML 渲染，保留上述官方字段
  - 新增回归测试，覆盖“repair 不改写”和“setEnabled 写回后字段仍保留”

## Codex MCP 未知字段保留策略
- 仅保留已知官方字段仍然不够，`setEnabled` 这类局部写回以前仍会把未知 server 键、未知工具字段和未知子表一起重渲染丢失。
- 当前把 Codex MCP 的 TOML 写回从“整段重渲染替换”改成“基于现有 block 的局部 merge”：
  - 已知受控键按当前状态更新或删除
  - 未知顶层键原样保留
  - 未知 `tools.<tool>` 子字段原样保留
  - 未知子表（例如未来官方新增 section 或用户自定义 section）原样保留
- 设计约束明确为：
  - 可以不在 UI 暴露未知字段
  - 但不能在一次 read-modify-write 之后吃掉未知字段
- 新增回归测试覆盖：
  - `setEnabled` 后仍保留未知 server 键
  - `setEnabled` 后仍保留 `tools.<tool>` 下未知字段
  - `setEnabled` 后仍保留未知嵌套表
