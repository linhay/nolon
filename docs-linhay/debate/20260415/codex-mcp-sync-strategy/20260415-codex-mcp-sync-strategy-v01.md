# codex-mcp-sync-strategy

**日期**：20260415
**模式**：合作型
**参与者**：Gemini（福尔摩斯）/ Codex（Beauvoir，法医）/ Claude（波洛，CLI 未返回有效内容，未纳入裁定）
**总轮次**：2 / 60
**结束原因**：第 2 轮达成有效参与者共识

## 辩论背景
> 用户要求就 “Nolon 将 `~/.nolon/mcps` 同步到 Codex 后，Codex 启动出现一批 MCP warnings” 商量解决方案。争议点不在 TOML 语法本身，而在同步边界与启用策略：哪些 server 应该被 Nolon 持续托管，哪些 server 应该因环境不可用而自动降级。

## 各轮观点记录

### 第 1 轮
**[Gemini - 福尔摩斯]**
- 论点：当前根因是 Nolon 盲目全量同步 cache entry，没有环境可用性判断。  
  引用：[MCPConfigManager.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/MCPConfigManager.swift#L173)  
  代码事实：`syncAllCacheServersToProvider` 直接遍历 cache entries 组装 `projected` 并回写 provider config。  
  结论：同步阶段应增加环境探测与自动降级。
- 论点：Codex 启用态默认不需要显式写出，当前配置中没有 `enabled = false` 的 server 都会被上游尝试初始化。  
  引用：[MCPConfigManager.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/MCPConfigManager.swift#L674) 、[types.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/codex/codex-rs/core/src/config/types.rs#L49)  
  代码事实：Nolon 只在禁用态写 `enabled = false`；上游 `enabled` 默认值是 `true`。  
  结论：`figma-desktop`、`xcode-tools` 这类当前不可用的 server 会在 Codex 启动时直接触发 warning。
- 首选方案：环境感知同步，针对 loopback HTTP 与会话型 Xcode MCP 在不可用时自动写 `enabled = false`。  
  次选方案：延迟按需同步。  
  不推荐方案：单纯调大 `startup_timeout_sec`。

**[Codex - Beauvoir]**
- 论点：除了环境感知，更大的问题是当前同步会覆盖 provider config 中所有非托管项。  
  引用：[MCPConfigManager.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/MCPConfigManager.swift#L173) 、[MCPConfigManager.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/MCPConfigManager.swift#L267)  
  代码事实：`syncAllCacheServersToProvider` 从空 `projected` 开始，最后整段 `writeServersDict`。  
  结论：只做环境感知还不够，必须修同步边界，避免误删用户手工配置。
- 论点：当前 `CodexMCPServer` 结构缺失 `cwd` / `bearer_token_env_var`，会导致 Nolon 对 Codex 配置做 round-trip 时丢字段。  
  引用：[CodexMCPConfig.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Models/CodexMCPConfig.swift#L95) 、[types.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/codex/codex-rs/core/src/config/types.rs#L100)  
  代码事实：本地模型未覆盖上游已支持字段。  
  结论：同步修正必须顺带补齐模型字段，不然配置保真仍有缺口。
- 首选方案：托管名单增量同步 + 可用性显式降级。  
  次选方案：给 MCP schema 增加显式 `autoDisableWhenUnavailable` 元数据。  
  不推荐方案：继续全覆盖写 `mcp_servers`。

### 第 2 轮
**[Gemini - 福尔摩斯，交叉审查 Codex 方案]**
- 认同点：保留非托管 server、对不可用 server 做 `enabled = false` 比物理删除更稳。  
  结论：同意把“托管集合 + 可用性降级”作为首选方向。
- 风险点：需要额外保护用户在 Codex 侧手动改过的托管 server，避免 Nolon 下次同步强行覆盖。  
  结论：应补“用户锁定/冲突提示”保护。

**[Codex - Beauvoir，交叉审查 Gemini 方案]**
- 认同点：环境感知降级必须做，尤其是 `figma-desktop` 的 loopback URL 与 `xcode-tools` 的会话型 env。  
  引用：[config.toml](/Users/linhey/.codex/config.toml#L46) 、[config.toml](/Users/linhey/.codex/config.toml#L56)  
  代码事实：当前 live config 中两者均处于启用态。  
  结论：这两类应在同步阶段自动转成 `enabled = false`。
- 保留意见：只做环境感知不够，因为仍然解决不了“哪些 server 允许被 Nolon 改写”的问题。  
  引用：[NolonResourceKitTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Tests/ProvidersTests/NolonResourceKitTests.swift#L677) 、[MCPLinkedSyncRegressionTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/MCPLinkedSyncRegressionTests.swift#L41)  
  代码事实：现有测试在保护旧的全覆盖语义。  
  结论：必须同时引入托管名单。

## 最终结论与行动项

### 达成共识 / 裁定结论
- 共识 1：当前 warning 的直接触发条件是 Nolon 同步后把 `figma-desktop`、`xcode-tools` 等当前不可用的 MCP 保持为启用态，而上游 Codex 对未显式禁用的 server 默认 `enabled = true`，启动时会立即初始化并在失败后输出 warning。  
  引用：[types.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/codex/codex-rs/core/src/config/types.rs#L49) 、[mcp_connection_manager.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/codex/codex-rs/core/src/mcp_connection_manager.rs#L287)
- 共识 2：**首选方案不是单点修补，而是组合方案**：  
  1. 把 Codex 同步改成“仅更新 Nolon 托管集合”的增量同步；  
  2. 对 loopback HTTP 与会话型 Xcode MCP 做可用性判断，不可用时保留配置但写 `enabled = false`；  
  3. 补齐 `cwd`、`bearer_token_env_var` 的模型/渲染支持。  
- 共识 3：不推荐只靠 `startup_timeout_sec` 兜底，也不推荐继续整段覆盖 `mcp_servers`。

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 改 `syncAllCacheServersToProvider`，保留非托管 server，并基于托管名单做增量更新/删除 | Codex / Nolon | 下一个实现轮次 |
| 2 | 为 `figma-desktop`、`xcode-tools` 增加同步期 availability gate，不可用时写 `enabled = false` | Codex / Nolon | 下一个实现轮次 |
| 3 | 给 `CodexMCPServer` 补 `cwd`、`bearer_token_env_var`，并打通读写与 TOML 渲染 | Codex / Nolon | 下一个实现轮次 |
| 4 | 改写覆盖旧语义的回归测试：保留非托管项、仅删除托管项、不可用时自动禁用但不删除 | Codex / Nolon | 下一个实现轮次 |
| 5 | 评估是否需要“用户锁定/冲突提示”保护，防止 Nolon 覆盖用户在 Codex 侧手工改过的托管项 | 待定 | 后续设计轮次 |

### 未解问题
- 托管名单状态文件应放在 `~/.nolon` 还是 provider 专属目录，尚未最终裁定，但共识是不应嵌回 `config.toml`。
- “环境不可用”的自动降级范围目前只对两类 server 达成共识：loopback HTTP、依赖 `MCP_XCODE_PID` / `MCP_XCODE_SESSION_ID` 的会话型 stdio。是否扩展到更多模式，需后续按误伤风险再定。
