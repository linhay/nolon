# Codex 配置写入治理与兼容性保护

## 背景
- `config.toml` 曾长期被多个模块分别读写，存在旧快照回写、整文件覆盖、旁路写入等问题，用户切账号时会丢失无关配置。
- Codex MCP 配置曾被 app 的 repair / 标准化链路被动改写；即使用户只做 enable/disable 这类局部操作，也会因为整段重渲染而丢失未知字段或未知子表，最终导致 MCP 失效。
- 这些问题已经出现真实事故，说明它不是某个单点 bug，而是配置资产治理缺位。

## 目标
- 为 Codex 主配置建立单一读写入口，统一文件级锁、原子写和 read-modify-write 语义。
- 为 Codex MCP 建立局部 patch 语义，明确 `preserve unknowns` 原则，禁止 canonical rewrite 吃掉未知参数。
- 明确哪些流程可以写原文件、哪些流程只能读，防止 repair / refresh / display 一类被动路径再次引入副作用。
- 给后续扩展字段、接入新入口、排查用户反馈提供稳定的回归和可观测性基础。
- 明确 Codex 账号云同步的页面边界：同步开关与冲突处理属于设置能力，入口放在设置页，不放在账号列表页。

## 范围
- `libs/Providers/Sources/Providers/Codex/CodexConfigStore.swift`
- `libs/Providers/Sources/NolonResourceKit/Infrastructure/MCPConfigManager.swift`
- `libs/Providers/Sources/ProviderUsage/CodexActiveProviderConfigManager.swift`
- `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift`
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexRefresh.swift`
- `nolon/Skills/Domain/Providers/Views/CodexAdvancedConfigSupport.swift`
- `nolon/Skills/Domain/Providers/Views/CodexConfigEditorView.swift`
- Codex 配置相关测试、治理文档与回归门禁

## 非目标
- 不做 TOML 全量格式化器，不追求把用户手写配置改成统一风格。
- 不在这条治理线中重做整个 MCP UI 建模；未知字段允许不暴露，但必须保留。
- 不处理仓外恶意程序绕过锁协议直接硬写文件的情况。

## 当前状态
- 已完成：
1. `config.toml` 仓内生产写路径已收口到 `CodexConfigStore`。
2. 已补进程内串行、跨进程 `.lock`、原子写。
3. 切账号 restore 已从“整份旧快照回写”改为“只撤 managed fragment”。
4. Codex provider 的被动 MCP repair 重写已停止。
5. Codex MCP 已知官方字段与未知字段/未知子表保留已补齐回归。
6. `ProviderMcpGridView` 创建原生 MCP 配置时的 Codex 直写旁路已改为共享入口 `MCPConfigManager.ensureNativeConfigScaffold(for:)`。
7. 已新增 `scripts/tests/codex-config-governance-smoke.sh`，用正则门禁扫描生产源码中的典型 Codex 配置直写旁路。
8. Codex iCloud 同步入口已从账号页迁到设置页（Advanced），账号页不再承载同步开关、清云动作、冲突处理或云同步摘要。
9. 启动期被动预检（`usage_load` / `background_poll`）发现当前选中的 Codex 账号已发生漂移时，不再自动继续保留选中态；会清空 active selection，并撤回该账号的托管 provider 配置。
- 待继续：
1. 把 MCP patch 职责从 `MCPConfigManager` 里再拆清，降低继续叠逻辑的风险。
2. 增加最小可观测性，记录关键配置写入来源与受控片段。

## 验收标准
1. Given app 内不同模块先后修改同一个 `config.toml`，When 变更都通过统一 store 落盘，Then 非冲突配置不会丢失。
2. Given relay 账号激活后 app 内又写入其他配置片段，When 切回 oauth 账号，Then restore 只撤 managed relay 配置，不回滚后续片段。
3. Given 用户的 Codex MCP server 含未知键、未知工具字段或未知子表，When 执行 enable/disable、install 或其他局部写操作，Then 这些未知内容保持原样。
4. Given 启动 repair、refresh、display 一类被动流程，When 未发生用户显式写操作，Then provider 原始配置文件不被改写。
5. Given 后续新增 Codex 配置写路径，When 合入主干，Then 必须经过统一入口或对应门禁会失败。
6. Given 用户查看 Codex 账号页，When 浏览账号列表与托管状态，Then 不出现 iCloud 同步卡；Given 用户进入设置页，When 打开 Advanced 配置，Then 能看到 iCloud 同步入口和冲突处理能力。
7. Given 启动或后台被动预检发现已选中账号对应的活跃 auth 内容被修改，When app 执行 `usage_load` 或 `background_poll`，Then 默认取消选中该账号，并恢复掉它注入的 managed relay 配置，不继续自动套用该账号状态。

## 关联文档
- [Codex config.toml 单一读写收拢](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/spaces/20260427-codex-config-store-unification/README.md)
- [Codex config store 实现说明](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/dev/codex-config-store-unification-2026-04-27.md)
- `libs/Providers/Sources/Providers/Codex/`
- `libs/Providers/Sources/NolonResourceKit/Infrastructure/MCPConfigManager.swift`
- `libs/Providers/Tests/ProvidersTests/`
