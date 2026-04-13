# 争论背景

用户反馈“现在 Codex 用量没有更新”。本轮争论的目标不是先改代码，而是先重新梳理当前 Nolon 的 Codex 用量获取链路，并和参考项目 `CodexBar` 的相关实现做对比，判断“没更新”究竟是没有触发刷新，还是刷新失败后被旧数据掩盖。

范围限定为 4 段：

- App 层多账号刷新链路
- Provider 层 Codex usage fetch 策略
- 失败后的缓存/状态处理
- 参考项目 `CodexBar` 的刷新与失效策略

# 参与者观点

## 第 1 轮

### GreyBox：当前最直接的问题，是 App 层把“刷新失败”伪装成了“沿用旧成功结果”

- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexRefresh.swift:298` 开始的失败分支，只更新 `lastSyncFailedAt/lastSyncFailureMessage`。
- 同文件 `:305` 调用 `shouldRetainExistingCodexSuccessResult(...)`，而 `:322` 之后的实现表明，只要当前内存里已有成功 outcome，就返回 `true`。
- 这意味着一次 timeout、401、网络失败之后，`codexAccountOutcomes` 里的旧成功配额仍会被保留，新的失败结果不会顶掉它。
- 这不是推测，测试已经把这个行为固化了：
  - `nolonTests/ProviderUsageEngineManualRefreshTests.swift:361`
  - 用例名就是 `GivenExistingCodexQuota_WhenRefreshFails_ThenRetainsPreviousSuccessOutcome`
  - `:439-445` 明确断言旧 email、旧 credits 继续保留，只额外写入 `request timed out`

结论：

- 当前 App 层对用户展示的是“旧成功快照 + 新失败元数据”
- 用户主观感受非常容易变成“我点了刷新，但用量没有更新”

### MirrorNode：这个坑在内部 CLI 服务里其实已经修过了，App 层现在和 CLI 出现了分叉

- `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:395-403`
- 这里的失败分支不是保留旧缓存，而是：
  - `clearUsageCache(for: account)`
  - `updateSyncFailure(...)`
- 也就是说，CLI 的语义是“刷新失败后旧快照已经不可信，必须失效”，而 App 的语义是“刷新失败也先继续显示旧快照”。
- 这和历史记忆是一致的：
  - `memory/2026-02-28.md:16`
  - 当时已经把这个问题定性为 Codex 用量“假正常”，并明确修成“失败时清缓存”

结论：

- 当前不是整个仓库都没考虑 stale cache
- 是 App 层 `ProviderUsageEngine` 没和 CLI 侧的修复语义保持一致

## 第 2 轮

### RefactorRaven：参考项目 CodexBar 也站在“失败即失效快照”这一边

- `docs-linhay/references/CodexBar/Sources/CodexBar/UsageStore+Refresh.swift:116-130`
- CodexBar 在 provider refresh 失败时，会把错误写入 `errors[provider]`，并直接 `snapshots.removeValue(forKey: provider)`。
- 这说明它宁可让 UI 进入 error/stale 态，也不保留旧 snapshot 继续冒充 fresh data。
- `docs-linhay/references/CodexBar/Sources/CodexBar/Providers/Codex/UsageStore+CodexAccountState.swift:63-83`
- 当 Codex active account 发生切换时，CodexBar 还会主动清空旧 snapshot、credits 和相关 failure gate，再重新拉取新账号数据。

结论：

- 参考项目的核心原则很明确：
- “刷新失败”与“账号切换”都不能继续沿用旧成功快照装作没事发生

### TokenSmith：当前 HTTP 用量查询链路少了一个关键步骤，失败概率因此被放大

- `libs/Providers/Sources/ProviderUsage/CodexHTTPUsageQuery.swift:301-348`
- 当前 `resolveConfiguration(...)` 只做了三件事：
  - 从 auth payload 里取 `access_token`
  - 取 `account_id`
  - 组装默认 ChatGPT `/wham/usage` 请求或读取显式 `nolon.usage_query`
- 这里没有读取 `refresh_token`，也没有在发起 usage query 前刷新 OAuth token。
- 但仓库其实已经有刷新能力：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManagerSupport.swift:13-81`
  - 可以直接向 `https://auth.openai.com/oauth/token` 刷新 token
- 只是这套能力现在只接在导入校验链路：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+ImportValidation.swift:205-223`
- 参考项目 `CodexBar` 的做法不同：
  - `docs-linhay/references/CodexBar/Sources/CodexBarCore/Providers/Codex/CodexProviderDescriptor.swift:139-145`
  - `docs-linhay/references/CodexBar/Sources/CodexBarCore/Providers/Codex/CodexOAuth/CodexTokenRefresher.swift:33-91`
  - 它会先判断 `needsRefresh`，必要时先刷新 token，再请求 `/wham/usage`

结论：

- Nolon 当前 HTTP query 比参考项目更容易撞到“access_token 已老化/失效”的失败场景
- 一旦失败，又会触发上一轮说的“保留旧成功结果”，于是用户看到的就是“还是旧用量”

## 第 3 轮

### GreyBox：当前 descriptor 的 fallback 策略也放大了问题的可见性

- `libs/Providers/Sources/ProviderUsage/Descriptors/CodexUsageDescriptor.swift:47-56`
- 当前策略是：
  - 如果是默认合成的 ChatGPT HTTP query，失败后可以继续走 CLI
  - 但如果是显式 `nolon.usage_query`，HTTP 一旦失败就直接返回 failure，不再 fallback
- 参考项目 `CodexBar` 的 OAuth strategy 更接近“auto 模式允许继续 fallback”：
  - `docs-linhay/references/CodexBar/Sources/CodexBarCore/Providers/Codex/CodexProviderDescriptor.swift:158-160`
- 这意味着在 Nolon 里，只要账号走的是显式 usage query，自定义/配置型账号的瞬时失败会更早暴露成 hard failure。
- 由于 App 层又保留旧成功 outcome，于是会出现最混淆的组合：
  - 刷新确实执行了
  - fetch 实际失败了
  - UI 仍然挂着上一轮成功额度

结论：

- “没有更新”并不等于“没有刷新”
- 更高概率是“刷新失败，但失败没有把旧值失效掉”

## 第 4 轮

### CacheTrace：这个 stale 不只是当前页面内存态，而是会被持久化并跨 reload / 重启继续复活

- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexRefresh.swift:259-273`
- App 层 refresh 成功后会把最新 `usage/credits` 写回 `CodexAuthUsageCache`。
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1069-1091`
- 这个 cache 不是临时内存，而是直接写进账号 `auth.json` 里的 `nolon.usage_cache`；只有显式调用 `clearUsageCache(for:)` 才会移除。
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:858-863`
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:1006-1011`
- App 每次 `load/reloadCodexFromDisk` 都会先 `loadCachedCodexAccountOutcomes(accounts:)`，把磁盘里的 `usage_cache` 恢复成成功 outcome。
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:1059-1117`
- 这里恢复 cache 的语义也是 `.success`，不是 stale/pending/failure。
- 测试也把“先展示 cache，再等 refresh”固化了：
  - `nolonTests/ProviderUsageEngineManualRefreshTests.swift:149-169`
  - `nolonTests/ProviderUsageEngineManualRefreshTests.swift:173-214`
  - 这两段用例都明确断言：preflight 没完成前先显示 `cached@example.com / 12 credits`，刷新成功后才切到 `fresh@example.com / 24 credits`。
- 再加上 `nolonTests/CodexAuthServiceTests.swift:28-66` 已验证 `usage_cache` 会真正持久化到 `auth.json`。

结论：

- App 层当前的 stale 不是“一次 refresh 失败时内存里没替换掉”这么简单。
- 更准确地说，是“成功快照被持久化到磁盘；失败时又没清缓存；下一次 load/reload 还会把它重新当成功结果加载回来”。

### UITrace：当前 UI 允许“失败状态 + 旧 quota”同时存在，所以用户更容易感知成“刷新没生效”

- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexRefresh.swift:900-927`
- `displayState(...)` 会优先看 `lastSyncFailureMessage/lastSyncFailedAt`，即使当前 `outcome` 仍然是 success，也会把卡片状态打成 `.failed` / `.needsReauth`。
- 但 `nolon/Skills/Domain/Accounts/Presentation/AccountCardModels.swift:422-439`
- 只要 `outcome.outcome.result` 还是 `.success`，`AccountRecordBuilder.codexUsage(...)` 依然会构造 quota body，继续渲染 usage/credits，`errorMessage` 还是 `nil`。
- 同一个 builder 在 `:459-489` 又会单独根据 failurePresentation 追加 `failureSummary/failureDetail`。
- 也就是说，当前模型层允许以下组合同时成立：
  - 卡片状态是失败/需重登
  - 错误摘要存在
  - 旧 quota/旧 credits 仍继续显示
- 这个分裂在展示层测试里也能侧面看到：
  - `nolonTests/CodexAccountDisplaySectionsTests.swift:368-389`
  - 这里 `outcome` 明明是 success（remaining 70），但只要 summary 里有 `lastSyncFailureMessage`，系统就把账号当成 errored 账号处理。

结论：

- 这进一步解释了为什么用户会说“没更新”而不是“报错了”。
- 因为产品当前不是纯 error UI，而是“错误元数据叠在旧成功快照上”。

### GateKeeper：自动刷新还有一个次级放大器，但它更像是 relay/configured 账号的问题，不是本案主因

- `libs/Providers/Sources/ProviderUsage/CodexAuthFailureClassifier.swift:21-30`
- 对非 `chatgptAccount` 且非 self-managed 的账号，只要出现 `lastSyncFailedAt/lastSyncFailureMessage`，`shouldSkipRefresh` 就会返回 `true`。
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:598-607`
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:642-655`
- 这会让定时刷新与 poll interval 直接跳过这些失败账号。
- 但 `ProviderUsageEngine.swift:681-688` 的 header refresh 仍会把全部账号纳入手动刷新队列；`nolonTests/ProviderUsageEngineManualRefreshTests.swift:1015-1045` 也覆盖了这一点。

结论：

- 所以它更像是“自动刷新迟迟不恢复”的次级放大器，尤其影响 relay / configured 账号。
- 但对于用户这次描述的“刷新后还是旧用量”，主因仍然是上面两层：失败不失效成功快照，以及快照会跨 reload 持久化。

## 第 5 轮

### ObserverProbe：第 4 轮大方向成立，但“存储介质”和“观察链路”需要再收窄

- 第 4 轮把 `usage_cache` 说成“直接写进账号 auth.json”，方向接近，但表述不够精确。
- 当前 managed Codex 账号的真实读写是 SQLite-backed payload：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SnapshotHelpers.swift:512-530`
  - `readAccountAuthData(...)` 直接从 SQLite 读回重建后的 auth payload。
  - `saveAccountAuthData(...)` 最终落到 `upsertCodexAccountInSQLite(...)`，不是简单覆写某个 snapshot 文件。
- `usage_cache` 真正持久化的位置也能在 SQLite upsert 里看到：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SQLite.swift:648-681`
  - 这里把 `json["nolon"]["usage_cache"]` 写入 `codex_account_metadata.usage_cache_json`。
- 所以第 4 轮更准确的说法应该是：
  - 旧成功快照会被持久化到 SQLite-backed auth payload / `usage_cache_json`
  - 之后 `loadCachedCodexAccountOutcomes(...)` 会把它重新恢复成 success outcome

结论：

- “stale 会跨 reload / 重启复活”这个判断成立。
- 但应避免把当前 managed store 误写成“主要靠 auth 文件目录中的单个 auth.json 文件变化驱动”。

### ObserverProbe：如果用量是被外部 CLI / 其他进程写回，当前 App 还有一条独立的观察盲区

- App 当前的 watcher 只监听两个路径：
  - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:780-791`
  - 默认 token accounts 文件
  - `nolonCodexAuthFolder()` 目录
- 但 managed Codex 账号的 `usage_cache` / `lastSync*` 更新，实际是 SQLite upsert：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SnapshotHelpers.swift:519-530`
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SQLite.swift:657-685`
- 当前对 SQLite 的 GRDB observation 只跟踪“表行数”：
  - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:938-948`
  - 只看 `codex_accounts / codex_account_credentials / codex_account_metadata / codex_active_accounts` 的 `COUNT(*)`
- 触发 reload 的条件也是这个计数快照发生变化：
  - `ProviderUsageEngine.swift:963-976`
- 这意味着：
  - 如果只是 `usage_cache_json`、`lastSyncFailedAt`、`lastSyncFailureMessage`、`plan_type` 这类字段被更新
  - 但表行数没变
  - 当前 observation 根本不会触发 `enqueueCodexReload(...)`
- 外部 CLI 刷新恰好就是这种写法：
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:193-197`
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:388`
  - `authUsageRefresh(...)` 最终通过 `storeUsageCache(cache, for: account)` 回写

结论：

- 如果症状是“在别的进程/CLI 已经刷新过，但 App 里的 Codex 用量还不变”，那么根因不只是 stale cache 语义，而是 App 没观察到 SQLite 字段级更新。
- 这条证据和“App 内手动刷新失败后继续展示旧值”是两类不同问题，不能混为一谈。

### ObserverProbe：因此目前最接近真相的判断，应该按触发路径拆成两个场景

- 场景 A：用户是在 App 内点击 Codex 卡片/页头刷新
  - 更可能的主因是：
    - refresh fetch 失败
    - 旧 success outcome 没失效
    - persisted `usage_cache` 也没清
  - 用户感知就是“刷新过，但还是旧用量”
- 场景 B：用户是在 CLI 或其他进程里刷新/登录/写回账号状态
  - 更可能的主因是：
  - App 只观察 auth folder + SQLite 行数
  - 没观察到 `usage_cache_json` / `lastSync*` 的字段级变化
  - 用户感知就是“外部已经更新，但 App 里没跟上”

## 第 6 轮

### RealityCheck：第 5 轮总体成立，但“观察缺口”的精确表述还需要再收一层

- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:773-792`
- 第 5 轮说“watcher 只监听两个路径”，这句话如果特指 `usageWatcher` 文件监听器，是成立的：它只 watch 默认 token accounts 文件与 `nolonCodexAuthFolder()`。
- 但如果把整个 App 的观察体系都算进去，这个表述不够完整，因为 App 还额外启了 SQLite GRDB observation：
  - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:916-979`
- 所以更准确的说法不是“完全没有观察 SQLite”，而是“已经观察了 SQLite，但观察模型只盯表行数快照”。

- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:172-177`
- `CodexSQLiteObservationSnapshot` 只有 4 个字段：`accountsCount / credentialsCount / metadataCount / activeCount`。
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:938-948`
- observation 查询出来的也正是这 4 个 `COUNT(*)`。
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:963-976`
- 即使 SQLite 对 metadata row 的 `UPDATE` 触发了回调，只要这 4 个 count 没变，`codexSQLiteObservationLastSnapshot != snapshot` 这个 guard 仍然会把 reload 吞掉。
- 因此，第 5 轮“字段级变化可能观测不到”这个结论是成立的，而且不依赖 GRDB 是否会对 `UPDATE` 发通知；本地的 count-only 去重已经足够把它压掉。

- `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SnapshotHelpers.swift:519-530`
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SQLite.swift:382-403`
- `saveAccountAuthData(...)` 最终是 `upsertCodexAccountInSQLite(...)`，这里只改 SQLite。
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:508-515`
- 真正把 SQLite payload materialize 成文件的是 `materializeManagedActiveAuthFile(...)`，它发生在 account activate / provider auth reconcile 路径，不是每次 `storeUsageCache(...)` 都会触发。
- 这意味着：
  - 外部 CLI 仅做 `auth usage refresh`
  - 并不会顺手改动 `nolonCodexAuthFolder()` 下的 watched 文件
  - App 想感知这次变化，基本只能依赖 SQLite observation

- 现有测试也只覆盖了 CLI 自己会把 stale cache 清掉：
  - `libs/Providers/Tests/ProvidersTests/NolonCodexCLIServiceTests.swift:422-423`
  - `libs/Providers/Tests/ProvidersTests/NolonCodexCLIServiceTests.swift:453-454`
  - `libs/Providers/Tests/ProvidersTests/NolonCodexCLIServiceTests.swift:644-657`
- 但目前没有证据表明仓库里已经覆盖了“外部 CLI metadata-only 写回后，App 会自动 reload”这一条集成路径。

结论：

- 第 5 轮的核心判断基本都是真的。
- 需要修正的只是表述精度：
  - 不是“App 没有 SQLite 观察”
  - 而是“App 现有 SQLite 观察只比较 count 快照，因此对 `usage_cache_json / lastSync* / plan_type` 这类 metadata-only 更新等价于没看见”
- 这让“外部刷新已成功，但 App UI 没同步”从一种合理猜测，升级成了高可信根因候选。

## 第 7 轮

### RootCauseForge：这次可以把“候选根因”升级成“已确认行为”，但仍然是两条根因链，不是单点问题

- App 内手动刷新这一条，已经不是“更可能”，而是代码层面可以直接确认：
  - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexRefresh.swift:298-330`
  - 失败分支只在 `!shouldRetainExistingCodexSuccessResult(...)` 时才替换 outcome。
  - `shouldRetainExistingCodexSuccessResult(...)` 的实现没有看错误类型、账号类型、失败次数，也没有看 cache freshness：
    - `ProviderUsageEngine+CodexRefresh.swift:322-330`
    - 只要当前内存里已经有一个 `.success`，它就恒为 `true`。
  - 这说明：
    - “刷新失败后继续展示旧成功结果”不是副作用，不是偶然，不是 UI 层误判。
    - 它就是当前 App 刷新语义的硬编码行为。
- stale 为什么会跨 reload 继续存在，也已经能直接确认：
  - 同一个失败分支没有 `clearUsageCache(for:)`：
    - `ProviderUsageEngine+CodexRefresh.swift:298-320`
  - 但 `reloadCodexFromDisk(...)` 每次都会重新走 `loadCachedCodexAccountOutcomes(accounts:)`：
    - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:850-863`
    - `ProviderUsageEngine.swift:1059-1117`
  - 而 `loadCachedCodexAccountOutcomes(...)` 会把 `usage_cache` 直接恢复成 `.success` outcome，不带 stale 标记。
  - 所以对 App 内刷新场景，可以把根因明确成：
    - 根因 1 = 失败不失效旧 success outcome
    - 根因 1a = 失败也不清 persisted `usage_cache`，导致旧成功快照可跨 reload 复活
- 外部 CLI/其他进程写回这一条，现在也可以从代码结构上确认不是“猜测”：
  - 外部刷新最终是 metadata row update：
    - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:193-197`
    - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:388`
    - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SQLite.swift:648-685`
  - App 侧 GRDB observation 的快照结构只有四个 count：
    - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:172-177`
  - `onChange` 里真正决定是否 reload 的 guard 也是 `lastSnapshot != snapshot`：
    - `ProviderUsageEngine.swift:963-976`
  - 因此只改 `usage_cache_json / lastSync* / plan_type / updated_at` 而不改表行数时，即便 observation 收到变更，当前本地去重也会把它吞掉。
  - 对跨进程刷新场景，可以把根因明确成：
    - 根因 2 = App 只比较 SQLite 行数快照，metadata-only 更新不会触发实际 reload
- UI 层不是第一根因，但它放大了用户体感：
  - `nolon/Skills/Domain/Accounts/Presentation/AccountCardModels.swift:387-505`
  - `nolon/Skills/Domain/Providers/Usage/Views/Common/UnifiedAccountCard.swift:91-105`
  - 模型允许“failure summary + success quota”共存，渲染层也会继续画 quota module。
  - 所以用户看到的不是“刷新失败”，而是“刷新过了但数字没动”。

## 第 8 轮

### PollingAudit：仓库里确实还有“auth 哈希轮询”这条链路，但它不能推翻根因 2

- `libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift:568-645`
- 仓库里确实有 `startProviderAuthPolling(for:)`：
  - 它轮询的是 provider 当前激活的 `auth.json`
  - 比较的是 auth file hash
  - 发现变化后，会把新的凭证 payload 回写进 SQLite
- 但这条链路解决的是“provider auth 文件凭证变化 -> SQLite snapshot 回收”，不是“SQLite usage metadata 变化 -> App Usage UI reload”。
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1198-1200`
- `currentAuthHashHex(for:)` 也只是读取 provider auth 文件 hash。
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexLogin.swift:657-666`
- App 侧对 `currentCodexAuthHashHex` 的使用，只是当 active account registry 缺失时辅助识别哪个账号当前激活，并没有把它接到 usage reload 判定上。
- 同时，外部 CLI 的 `authUsageRefresh(...)` 并不会去 materialize managed active auth file：
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:193-197`
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:388-402`
  - 它只会更新 SQLite-backed account metadata（`usage_cache` / `lastSync*`）。

结论：

- “provider auth polling / auth hash” 不是第三条隐藏修复路径。
- 它不能覆盖外部 CLI 刷新造成的 metadata-only 写回，所以也不能推翻根因 2。

## 第 9 轮

### TraceLock：已按新增证据回到代码复核，结论是“auth polling”只会加强根因 2，不会削弱它

- 新证据提到的 provider auth polling 确实存在：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift:568-645`
  - 这段逻辑只做一件事：
    - 轮询 provider 当前激活 `auth.json`
    - 比较 hash
    - hash 变化时把新的 auth payload 重新 `upsert` 回 SQLite
- 但它的输入源始终是 provider auth file，而不是 SQLite metadata：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1198-1200`
  - `currentAuthHashHex(for:)` 本身也只读 provider auth file hash。
- App 侧也没有把这个 hash 接成 usage refresh 触发器：
  - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexLogin.swift:657-666`
  - `currentCodexAuthHashHex` 只是用来在 active registry 丢失时辅助判断哪张卡当前处于 active。
- 与此同时，外部 CLI 的 `authUsageRefresh(...)` 仍然只是写 SQLite metadata：
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:193-205`
  - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:388-402`
  - 这里会更新 `usage_cache` / `lastSync*`，但不会 materialize provider auth file，也不会制造新的 auth hash 变化。
- 所以把这几段放在一起看，链路其实更清楚了：
  - provider auth polling 负责“auth 文件变化 -> SQLite”
  - App Usage UI reload 负责“文件 watcher / SQLite observation -> 重新 load”
  - 外部 CLI usage refresh 只命中了“SQLite metadata update”这一步
  - 而 App 现有 SQLite observation 又只比较 count 快照
  - 因此外部 usage refresh 仍会卡在最后一跳，UI 不会自动跟上

结论：

- 新证据没有引入第三条能自愈的同步路径。
- 它实际把链路切得更干净了：
  - auth polling 是“凭证同步链”
  - 当前争议的是“usage freshness 同步链”
- 因此本案根因仍维持不变：
  - App 内刷新问题，根因是失败不失效旧 success/cache。
  - 外部写回问题，根因是 metadata-only SQLite 更新被 count-only observation 吞掉。

结论：

- 现在可以更明确地说：
  - 没有单一“总根因”。
  - 已确认的根因是两条：
    - App 内刷新链路：失败后保留旧 success，并保留 persisted cache。
    - 外部写回链路：SQLite metadata-only 更新被 count-only observation 吞掉。
- 如果一定要再上收一层抽象，统一表述应是：
  - 当前 Codex 用量系统对“freshness”只有成功快照的写入路径，没有对等完整的失效路径和跨进程变更感知路径。

## 第 9 轮

### GreyBox：已复核第 8 轮新增证据，结论成立，但它只是否定了一个“伪反例”

- 我们刚刚回到代码把第 8 轮逐点核过了一遍：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift:568-645`
  - `startProviderAuthPolling(for:)` 的确只轮询 provider 当前 `auth.json` 的 hash 变化，并在变化时把 payload 重新 upsert 到 SQLite。
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1198-1200`
  - `currentAuthHashHex(for:)` 也的确只是 provider auth 文件 hash。
  - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexLogin.swift:657-666`
  - App 侧当前对这个 hash 的消费，只是拿来辅助识别“哪张卡是 active”，不是拿来触发 usage reload。
- 因此第 8 轮的价值在于：
  - 它排除了一个常见误判：
    - “既然仓库里有 auth polling / auth hash，那外部 CLI 刷新也许最终还是会绕回来触发 UI 同步。”
  - 现在可以确认这条绕回路径并不存在。
- 但它没有改变主结论，只是让主结论更稳：
  - 外部 CLI 的 `authUsageRefresh(...)` 仍然只是改 SQLite metadata：
    - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:193-205`
    - `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift:388-402`
  - App 仍然只用 count-only snapshot 决定是否 reload：
    - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:172-177`
    - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:938-976`

结论：

- 新证据没有推翻“根因 2”，反而把它从“高可信”进一步压实成了“已复核成立”。
- 现在更准确的说法是：
  - `auth polling / auth hash` 只覆盖凭证文件变化；
  - 它不覆盖 usage metadata 变化；
  - 所以它不是外部 CLI usage refresh 的补救同步机制。

# 结论与行动项

## 结论

- 当前 debate 已从“接近真相”收敛到“已确认两条根因链”：
  - App 内手动刷新：失败后旧 success outcome / persisted cache 没失效。
  - 外部 CLI/其他进程写回：App 的 count-only SQLite observation 吞掉了 metadata-only 更新。
- 因此不能再笼统地把所有“没更新”都归到一个点上，也不应该继续把它描述成单一根因候选。
- 当前 UI/模型层还进一步放大了这种体感：它允许“失败摘要”和“旧 quota”同时展示，而不是在失败时让旧数据失效或明确标注 stale。
- 当前最可能的次因是 Codex HTTP usage query 没有像参考项目那样先做 OAuth token refresh，导致失败概率偏高。
- 当前最需要对齐的不是 UI 文案，而是数据语义：
  - 失败时旧 quota 是否还能继续展示成 fresh data
  - 失败时旧 `usage_cache` 是否还能继续持久化并参与下一轮 load/reload
  - 外部写回 SQLite metadata 时，App 的 count-only observation 是否会把字段级变化吞掉
  - token 老化时是否先 refresh 再 query

## 行动项

1. App 层对齐 CLI/参考项目语义：
    - 非 self-managed 账号刷新失败时，不再保留旧成功 outcome。
    - 需要同步清理 `usage_cache`，并让内存状态切到 failure/pending，而不是继续挂着旧 quota。
    - 这一步必须同时覆盖“当前内存态”和“下次 load/reload 的磁盘态”，否则 stale 还会反复复活。
2. 把 OAuth refresh 接进 Codex usage fetch：
    - 至少对 ChatGPT OAuth/default query 路径，优先使用现有 refresh helper 更新 token 后再请求 `/wham/usage`。
3. 补齐 SQLite metadata 的观察维度：
    - 当前只观察 `COUNT(*)` 不够，需要让 `usage_cache_json` / `lastSync*` / `plan_type` / active account 变更也能触发 reload。
    - 至少要把 `CodexSQLiteObservationSnapshot` 从“行数快照”升级为“字段变化快照”或 `updated_at` 级别快照，否则 metadata-only update 仍会被本地去重吞掉。
    - 或者直接明确：App 内刷新只认本进程状态，跨进程写回不做实时同步。
4. 重新审视 explicit `usage_query` 的 fallback 策略：
    - 需要区分“真的应该 hard fail 的 relay/configured account”与“只是 OAuth token 过期的 ChatGPT account”。
5. 明确失败态展示语义：
    - 如果产品仍想保留旧快照做参考，也不能继续把它当 fresh success 渲染；至少需要显式 stale 标记，或直接隐藏 quota body。
6. 先补 BDD/TDD，再改实现：
    - `Given stale success outcome when refresh fails then app invalidates cached quota`
    - `Given persisted usage cache when refresh fails then reload no longer restores stale quota as success`
    - `Given success outcome plus persisted failure metadata then card does not render stale quota as fresh data`
    - `Given external CLI updates usage_cache_json without row-count changes then app reload trigger still fires`
    - `Given sqlite metadata row updates without count changes then Codex GRDB observation still enqueues reload`
    - `Given expired OAuth token when usage query runs then token is refreshed before wham usage request`
    - `Given explicit usage query transient failure when account is ChatGPT-like then fallback policy is explicit and testable`

## 第 10 轮

### GreyBox：已进入实现闭环，前两条主根因已各自拿到代码修复与回归

- 这轮不再只是分析，已经在代码里完成了两条根因链的最小修复，并通过对应 BDD 回归。
- 已落地的修复 1：
  - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexRefresh.swift`
  - 非 self-managed Codex 账号刷新失败时，不再保留旧 `.success` outcome。
  - 同时清理 `usage_cache`，避免旧 quota 在下一轮 disk reload 中复活。
- 已落地的修复 2：
  - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift`
  - `loadCachedCodexAccountOutcomes(...)` 现在会读取 `codexAccountSummaries`。
  - 当 SQLite 中已存在 persisted failure metadata 时，reload 不再把旧 `usage_cache` 恢复成 fresh success。
- 已落地的修复 3：
  - `ProviderUsageEngine.reloadCodexFromDisk(...)` 结束后会同步刷新 usage watcher。
  - 这样测试路径和真实运行时路径都能在 disk reload 后立刻开始监听 SQLite / WAL / SHM 变化，不再只依赖 `load()`。
- 已落地的修复 4：
  - `CodexSQLiteObservationSnapshot` 从纯 `COUNT(*)` 扩展为包含 `MAX(updated_at)`。
  - 同时 `updateUsageFileWatcher()` / `handleCodexUsageFileChange(_:)` 已显式纳入 SQLite db、父目录、`-wal`、`-shm`。
  - 这让 “metadata-only 更新” 至少有一条稳定触发 reload 的路径，不会再被路径层面直接漏掉。
- 额外校正：
  - 外部写回链路的 BDD 测试原先只等 `codexDiskReloadCount >= 2`，存在竞态。
  - 现在测试改为等待 outcome 真正变成外部写回值，再断言 email / credits。
  - 这不是放宽标准，而是把判定条件从“reload 已开始”修正为“reload 已生效”。

### 本轮验证

- 已通过定向测试：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageEngineManualRefreshTests/testBDD_GivenExistingCodexQuota_WhenRefreshFails_ThenInvalidatesPreviousSuccessOutcomeAndClearsUsageCache -only-testing:nolonTests/ProviderUsageEngineManualRefreshTests/testBDD_GivenPersistedUsageCacheAndFailureMetadata_WhenReloadingFromDisk_ThenDoesNotRestoreStaleQuotaAsSuccess -only-testing:nolonTests/ProviderUsageEngineManualRefreshTests/testBDD_GivenExternalSQLiteMetadataOnlyUpdate_WhenObservationActive_ThenReloadsCachedOutcomes`
  - 结果：`TEST SUCCEEDED`
- autoresearch 机械指标也已从 `2 -> 0`：
  - 旧的两个 root-cause marker 都已从源码中消失。

### 结论更新

- 截至本轮，前面 debate 收敛出的两条主根因已不再只是“判断成立”，而是“已有实现修复 + 有测试回归”。
- 还未处理的剩余问题，已经从“主根因”下降为“次级收尾项”：
  - OAuth token refresh 何时接入 usage fetch
  - explicit `usage_query` fallback 是否要按账号类型分流
