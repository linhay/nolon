# Provider Usage 业务域拆分与页面边界计划

日期：2026-04-15

## 背景

本轮已经确认：

1. 当前 `Provider Usage` 不拆成“账号页 / 用量页”两个页面。
2. 真正需要优先解决的是代码职责边界，而不是先改导航。
3. `usage` 已经横跨账号激活态与 session / cost 数据源，应当逐步提升为独立业务域。

依据文档：

- `docs-linhay/dev/provider-usage-account-usage-boundary-design-2026-04-15.md`
- `docs-linhay/debate/20260415/accounts-vs-usage-page-split/20260415-accounts-vs-usage-page-split-v01.md`

## 目标

1. 保持当前“账号 + 用量”同页体验不回归。
2. 把账号域与用量域拆成独立加载、独立状态、独立测试边界。
3. 为未来可能的 UI 拆页保留低成本路径，但不在本轮强推页面改造。

## BDD 场景

1. `Given ProviderUsage 页面首次打开 when 只需要账号信息 then 账号域可以独立加载且不要求同时刷新 usage trend`
2. `Given ProviderUsage 页面已打开 when 用户只刷新历史 Token 消耗 then 只触发 usage 域刷新，不回刷账号域`
3. `Given intraday drilldown 已展开 when 用户切换日级 range 或 minute bucket then 仅 usage 域状态变化，不影响账号卡片状态`
4. `Given 账号发生激活/删除/导入变更 when usage 域没有依赖该动作的展示刷新 then 不应无条件触发全页统一 reload`
5. `Given 未来需要把 usage 提升为独立页面 when 路由切换后 then 账号域与 usage 域仍可按各自入口独立装配`

## Phase 划分

### Phase 0：文档冻结与测试基线

目标：

1. 把页面边界与业务域边界的结论写清楚。
2. 先补能证明当前耦合点的测试，不急着改实现。

执行项：

1. 冻结设计文档与本计划。
2. 新增或补齐以下测试：
   - `ProviderUsageRootViewModel` 的 load 路径测试
   - `ProviderTokenTrendViewModel` 独立行为测试
   - `ProviderUsageAccountsViewModel` 与 `ProviderTokenTrendViewModel` 的 wiring 测试
3. 明确当前哪些行为仍共享 `commonEngine`，作为后续拆分前提。

完成标志：

1. 文档可作为后续重构唯一口径。
2. 关键耦合点有测试保护。

### Phase 1：先拆 Usage 域状态所有权

目标：

1. 让 `usage` 不再只是 `commonEngine` 上的一组字段。
2. 保持 UI 仍是同页。

执行项：

1. 从当前 `ProviderUsageEngine` 中抽离 usage 相关状态：
   - `tokenTrendRange`
   - `tokenTrendSnapshot`
   - `selectedTokenTrendDayKey`
   - `intradayBucket`
   - `intradaySnapshot`
   - `tokenTrendErrorMessage`
   - `intradayErrorMessage`
2. 为 usage 提供独立的 load / refresh 接口：
   - `loadUsageIfNeeded()`
   - `refreshTokenTrend()`
   - `refreshIntraday()`
3. `ProviderTokenTrendViewModel` 改为只依赖 usage store / usage engine。
4. 确保 Gemini / Codex 的 usage 数据源继续留在 `libs/Providers`。

完成标志：

1. 账号 VM 与趋势 VM 不再共享同一个 `commonEngine`。
2. 刷新历史 Token 消耗不必经过账号 load 入口。

### Phase 2：拆加载入口与刷新策略

目标：

1. 让 root 只负责编排，不再让账号域承担全页统一 load 入口。

执行项：

1. `ProviderUsageRootViewModel` 提供显式入口：
   - `loadAccountsIfNeeded()`
   - `loadUsageIfNeeded()`
   - `loadPageIfNeeded()`
2. 页面初始加载策略改为：
   - 首屏默认先拉账号域
   - 需要显示 usage 的 provider 再单独触发 usage 域初始加载
3. 手动刷新按钮按域分发，避免全页大刷。
4. 清理“账号 load 顺手拉 trend”的隐式逻辑。

完成标志：

1. root 层 load 语义清晰。
2. 账号与用量的刷新路径彼此独立。

### Phase 3：页面拆分 Gate

目标：

1. 不是直接拆页，而是设一个明确的决策门。

触发条件：

1. `UsageFeature` 已完成独立 store / engine / load 边界。
2. 同页布局已出现明确导航压力，或产品明确要求独立路由。
3. 测试证明拆路由不会引入并行事实源或重复加载。

若触发，则执行：

1. 把当前 `tokenTrendSection` 提升为独立 route / tab / page。
2. Root 继续作为编排层，为两个页面提供共享上下文。
3. 不回退到“页面拆了，但还共用一坨 engine”的结构。

## 推荐代码落点

1. `nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageRootViewModel.swift`
2. `nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageStateStore.swift`
3. `nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageSubViewModels.swift`
4. `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift`
5. `libs/Providers/Sources/ProviderUsage/GeminiTokenTrendService.swift`
6. `libs/Providers/Sources/ProviderUsage/GeminiIntradayUsageService.swift`
7. `libs/Providers/Sources/ProviderUsage/CodexTokenTrendService.swift`
8. `libs/Providers/Sources/ProviderUsage/CodexIntradayUsageService.swift`

## 测试门禁

### 先补失败测试

1. `Given root loads page when usage is enabled then accounts and usage can be invoked independently`
2. `Given token trend refresh when accounts state is unchanged then accounts VM does not reload`
3. `Given account mutation when usage snapshot is cached then usage state is not reset unless explicitly invalidated`
4. `Given Gemini / Codex usage source when page route changes then usage data source remains single and shared`

### 定向验证

1. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS'`
   - 至少覆盖 `ProviderUsageRootViewModel`、`ProviderTokenTrendViewModel`、`ProviderUsageAccountsViewModel` 相关测试
2. `swift test --package-path libs/Providers`
   - 至少覆盖 Gemini / Codex trend 与 intraday service

## 风险与防线

### 风险 1：拆状态后，账号动作与用量数据失去同步

防线：

1. 只拆状态所有权，不拆 provider usage 事实源。
2. 明确哪些账号动作需要显式 invalidation usage。

### 风险 2：拆 load 入口后出现双重加载

防线：

1. root 层保留唯一编排入口。
2. usage 域必须具备 `loadIfNeeded` 语义。

### 风险 3：先做了大量结构化，最终却不拆页

防线：

1. 结构化本身必须能提升同页版本的可维护性。
2. Phase 3 采用 Gate，而不是默认承诺最终一定拆页。

## 非目标

1. 本计划不承诺当前版本一定拆成两个页面。
2. 本计划不重做既有 intraday 交互规格。
3. 本计划不把 Codex Sessions Tab 直接并入本轮重构范围。

## 执行状态

### 2026-04-15 Phase 0 - 2 前台落地结果

已完成：

1. `ProviderUsageEngineProtocol` 已拆为 `ProviderUsageAccountsEngineProtocol` 与 `ProviderUsageMetricsEngineProtocol`，账号域与 usage 域不再共用 `commonEngine` 接口。
2. `ProviderUsageStateStore` 已显式暴露 `accountsEngine` / `metricsEngine`。
3. `ProviderTokenTrendViewModel` 已改为只依赖 `metricsEngine`。
4. `ProviderUsageRootViewModel` 已新增 `loadAccountsIfNeeded()`、`loadUsageIfNeeded()`、`loadPageIfNeeded()`，并把旧 `load()/loadIfNeeded()` 收敛为 page orchestration 入口。
5. `ProviderUsageView` 首屏 `.task` 与 provider 切换逻辑已改走 `loadPageIfNeeded()`。
6. `ProviderUsageEngine.load()` 已移除“账号 load 顺手拉 trend”的隐式链路，usage 改由 `loadUsage()/loadUsageIfNeeded()` 单独触发。
7. 已补齐 root 级边界测试：`ProviderUsageRootLoadBoundaryTests`。

验证结果：

1. boundary violation metric 从 `8` 降到 `0`。
2. 定向验证命令通过：
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageRootLoadBoundaryTests -only-testing:nolonTests/ProviderUsageSubViewModelWiringTests -only-testing:nolonTests/ProviderTokenTrendViewModelParityTests -only-testing:nolonTests/ProviderUsageAccountsViewModelParityTests -only-testing:nolonTests/ProviderUsageLoginFlowViewModelParityTests -only-testing:nolonTests/GeminiUsageTokenTrendViewModelTests -only-testing:nolonTests/ProviderUsageEngineManualRefreshTests -only-testing:nolonTests/ProviderUsageUnifiedAccountsPipelineTests -only-testing:nolonTests/ProviderUsageEngineActivationTests`

待后续继续观察：

1. 非 Codex 头部 refresh 目前已自然收敛为账号域 refresh；若后续产品要求“头部一键刷新全页”，需要再明确 page-level refresh 语义，而不是回退到隐式耦合。

### 2026-04-16 Phase 3 - Provider 详情页双 Tab 首批落地

已完成：

1. `ProviderContentTabType.availableTabs(for:)` 已对 `codex`、`gemini`、`antigravity` 自动补出独立 `accounts` tab，并保持位于 `usage` 之前。
2. `ProviderDetailGridView` 已把 `.accounts` 与 `.usage` 分别映射到 `ProviderUsageView(pageMode: .accounts/.usage)`；非拆分 provider 的 `usage` 继续走 `combined` 兼容模式。
3. `ProviderUsageRootViewModel` 已新增 `ProviderUsagePageMode`，支持按页面模式分发标题、page marker 与 `loadIfNeeded` 入口。
4. `ProviderUsageView` 已完成页面内容拆分：
   - `Accounts` 只渲染账号区
   - `Usage` 只渲染 token trend
   - `combined` 继续保留给全局账号中心与未拆分 provider
5. 已补齐双 tab 配置测试：`ProviderAccountUsageTabConfigurationTests`。

验证结果：

1. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderAccountUsageTabConfigurationTests -only-testing:nolonTests/ProviderUsageRootLoadBoundaryTests -only-testing:nolonTests/CodexSessionsTabConfigurationTests -only-testing:nolonTests/GeminiUsageTabConfigurationTests -only-testing:nolonTests/ProviderUsageSubViewModelWiringTests -only-testing:nolonTests/ProviderTokenTrendViewModelParityTests -only-testing:nolonTests/ProviderUsageAccountsViewModelParityTests`
2. 结果：`20` 个定向测试通过，`0` 失败。

当前保留限制：

1. `claude` 已进入本轮双 tab，`Usage` 页通过本地 Claude session 日志聚合提供日级 trend 与 intraday drilldown，不再依赖“同页账号区顺手带出 usage”。
2. `codexXcode` 仍保持不暴露 `accounts`，账号与用量继续交给 Xcode 自身管理。
