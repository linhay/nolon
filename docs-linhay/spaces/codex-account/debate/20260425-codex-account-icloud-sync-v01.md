# Codex 账号 iCloud 同步 debate

**日期**：20260425
**模式**：合作型
**参与者**：Gemini（外部审查者）
**总轮次**：2 / 60
**结束原因**：第 2 轮达成共识

## 执行元数据
- 候选参与者：Gemini
- 首轮实际启用：Gemini
- 后续 active participants：Gemini
- 淘汰参与者：无
- 不可用原因：无

## 辩论背景
> 主题是 `docs-linhay/spaces/codex-account/README.md` 中“Codex 账号支持 iCloud 同步”的需求设计。
> 核心待审问题：
> 1. 是否应该只同步账号库而不同步当前激活态
> 2. `accountID` / auth hash / email 的覆盖规则是否合理
> 3. 删除传播与“激活失效待处理”是否合理
> 4. 是否遗漏了某个必须同步或必须禁止同步的层

## 主持人提供的代码事实
- [docs-linhay/spaces/codex-account/README.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/spaces/codex-account/README.md:7)
  当前需求明确账号管理会联动 provider `auth.json`、活跃账号 registry 和 `config.toml`。
- [docs-linhay/spaces/codex-account/README.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/spaces/codex-account/README.md:81)
  当前需求明确“账号库同步”与“账号激活”分离。
- [libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1204)
  当前激活态既看 registry，也看 provider `auth.json` 内容 / symlink 解析结果。
- [libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1342)
  激活账号会同时触发 `activateAccount`、`setActiveAccount`、`syncActiveProviderConfig`。
- [libs/Providers/Sources/ProviderUsage/CodexAuthManager+ActiveProviderConfig.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/CodexAuthManager+ActiveProviderConfig.swift:74)
  `syncActiveProviderConfig` 会改写本地 `config.toml` 并可能迁移 session provider。
- [libs/Providers/Sources/ProviderUsage/CodexAuthAccount.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/CodexAuthAccount.swift:42)
  账号摘要包含 `email`、`accountID`、`lastLoginAt`、`lastSyncSucceededAt` 等元数据。

## 各轮观点记录

### 第 1 轮
**[Gemini]**

#### 观察到的代码事实
1. 账号与 relay 配置耦合。  
   论点 → 引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager+ActiveProviderConfig.swift:156` → 代码事实：`relayConfig(from:object:...)` 直接从账号 snapshot 解析 relay 配置。→ 结论：同步账号记录时，天然会带着该账号的 relay 接管参数。
2. 当前激活态是文件驱动。  
   论点 → 引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1216`、`1224` → 代码事实：当前活跃账号既可能来自 symlink 目标，也可能来自 provider `auth.json` 现有内容匹配。→ 结论：本地激活态不是单纯数据库字段，不能跨设备直接同步。
3. preflight 会自动对齐配置。  
   论点 → 引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1267`-`1269` → 代码事实：`preflightManagedAuthIfNeeded` 会在 reconcile 后调用 `syncActiveProviderConfig`。→ 结论：如果边界收不紧，云端同步后的账号可能间接影响本地运行配置。
4. 账号摘要含同步元数据。  
   论点 → 引用：`libs/Providers/Sources/ProviderUsage/CodexAuthAccount.swift:146` → 代码事实：账号摘要读取 `lastLoginAt`、`lastSyncSucceededAt`、`lastSyncFailedAt`。→ 结论：覆盖规则若只看 hash，可能导致元数据倒退。

#### Gemini 结论
- 结论：有条件同意，需收紧边界。

#### Gemini 的有效异议
1. 删除 tombstone 后的本地残留处理不够具体。  
   论点 → 引用：`docs-linhay/spaces/codex-account/README.md:99`、`libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1359` → 代码事实：需求要求删除传播不主动删除其他设备当前激活的 provider `auth.json`；代码中 `reconcileDetachedProviderAuthIfNeeded` 仍依赖 snapshot 体系做托管对齐。→ 结论：若云端删掉记录但本地还残留 provider 文件，容易形成“孤儿 auth 文件 / 脱离托管”状态，需求应明确下一步处理策略。
2. `accountID` 缺失时仅凭 auth hash 自动合并过于激进。  
   论点 → 引用：`docs-linhay/spaces/codex-account/README.md:88`、`libs/Providers/Sources/ProviderUsage/CodexAuthAccount.swift:52`-`55` → 代码事实：需求允许 hash 命中即自动合并；摘要模型又含多个同步时间字段。→ 结论：若两个设备持有相同凭据但不同本地同步元数据，仅按 hash 合并可能让较新的元数据被旧值覆盖，需求应补“较新时间戳优先”或其他逻辑时钟规则。
3. “激活态不同步”是正确方向。  
   论点 → 引用：`docs-linhay/spaces/codex-account/README.md:26`、`libs/Providers/Sources/ProviderUsage/CodexAuthManager+ActiveProviderConfig.swift:74` → 代码事实：激活会触发本地 `config.toml` 改写与会话 provider 迁移。→ 结论：这一层必须保持设备本地化，否则后台同步会破坏当前机器运行环境。

#### Gemini 的收紧建议
1. 当云端 tombstone 删除账号，而本地仍存在有效 provider `auth.json` / snapshot 残留时，需求应明确系统行为：
   - 未激活：自动清理本地残留
   - 已激活：进入“激活失效待处理”，并要求用户重新导入或清理残留
2. 当 `accountID` 缺失但 auth hash 命中时，覆盖规则应补充：
   - 凭据视为同一账号
   - 元数据字段按较新 `updatedAt` / 逻辑时钟合并，不允许旧同步时间覆盖新同步时间
3. 虽然不同步当前激活选择，但同步到新设备的 relay 默认参数必须保持“只入库、不落本地 `config.toml`”，只有手动激活时才允许注入运行配置。

### 第 2 轮
**[Gemini]**

#### 观察到的代码事实
1. 元数据结构已具备字段级合并基础。  
   论点 → 引用：`libs/Providers/Sources/ProviderUsage/CodexAuthAccount.swift:42`-`54` → 代码事实：`CodexAuthSummary` 已包含 `email`、`accountID`、`lastLoginAt`、`lastSyncSucceededAt`、`lastSyncFailedAt`、`lastSyncFailureMessage`。→ 结论：可以安全定义“字段级最大值合并”。
2. 元数据提取路径稳定。  
   论点 → 引用：`libs/Providers/Sources/ProviderUsage/CodexAuthAccount.swift:164`-`166` → 代码事实：`fromJSONData` 已统一从 JSON 提取身份与同步元数据。→ 结论：跨设备识别和合并有统一入口。
3. 激活态文件同步已受 active account 约束。  
   论点 → 引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager+ActiveProviderConfig.swift:123`-`134` → 代码事实：`refreshActiveProviderFilesIfNeeded` 仅在账号处于当前激活态时才刷新本地文件与配置。→ 结论：只要需求写清楚“同步入库不自动激活”，实现上有可落点。
4. `preflight` 已是托管自愈入口。  
   论点 → 引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1267`-`1271` → 代码事实：`preflightManagedAuthIfNeeded` 会统一做 reconcile 和配置自愈。→ 结论：这里适合承接“tombstone + 本地激活残留时必须人工决策”的状态返回。

#### Gemini 第 2 轮结论
- 结论：已共识。

#### Gemini 第 2 轮裁定
1. tombstone 后未激活账号直接清理残留，可以关闭“孤儿 auth 文件”风险。  
   论点 → 引用：方案 A → 代码事实：新增“未激活即清理本地账号记录、snapshot 与托管残留文件”的规则。→ 结论：已共识。
2. 激活态 tombstone 进入“激活失效待处理”，并禁止 `preflight` 静默重建托管账号，可以关闭“后台自愈绕过用户决策”风险。  
   论点 → 引用：方案 A、`CodexAuthManager.swift:1267`-`1271` → 代码事实：`preflight` 本来就是统一自愈入口。→ 结论：已共识。
3. `accountID` 缺失但 hash 命中时采用字段级较新值合并，可以避免同步元数据倒退。  
   论点 → 引用：方案 B、`CodexAuthAccount.swift:42`-`54` → 代码事实：现有模型已有对应时间字段。→ 结论：已共识。
4. relay 参数“入库但不落本地 `config.toml`，除非手动激活”可以维持设备隔离。  
   论点 → 引用：方案 C、`CodexAuthManager+ActiveProviderConfig.swift:123`-`134` → 代码事实：本地配置刷新已依赖 active account。→ 结论：已共识。

## 最终结论与行动项

### 达成共识 / 裁定结论
- Gemini 对主方案达成共识：`v1` 继续维持“只同步账号库，不同步当前激活态”。
- 第 1 轮提出的两个阻塞点已在第 2 轮通过三项收紧方案关闭：
  1. tombstone 删除后的本地残留治理
  2. `accountID` 缺失但 hash 命中时的字段级合并
  3. relay 参数“只入库，不自动写本地运行配置”
- 主持人裁定：方案已达到需求级共识，可以进入 README 修订与后续实现计划拆分。

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 在 `README.md` 补充 tombstone 删除后的本地残留处理规则 | Codex | 已完成 |
| 2 | 在 `README.md` 补充 hash 命中时的元数据合并规则 | Codex | 已完成 |
| 3 | 在 `README.md` 明确 relay 参数同步后仅入库，不自动写 `config.toml` | Codex | 已完成 |

### 未解问题
- 是否需要把“账号记录 payload 更新时间”单独提升为显式字段，而不是依赖现有同步时间字段近似判断；该问题不阻塞当前需求级共识。
