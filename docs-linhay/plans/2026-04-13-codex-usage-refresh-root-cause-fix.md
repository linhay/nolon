# Codex 用量刷新根因修复计划

日期：2026-04-13

## 背景
- 当前 `Codex` 用量“不更新”已经收敛为两条已确认根因链：
  - App 内手动刷新失败后，旧 success outcome 与 persisted `usage_cache` 没有失效。
  - 外部 CLI/其他进程只更新 SQLite metadata 时，App 的 count-only observation 不会触发 reload。
- 本轮不扩 scope 到 OAuth refresh；先把已确认主根因修掉，并补齐回归测试。

## 目标
1. 刷新失败后不再继续把旧 quota 当作 fresh success 展示。
2. persisted `usage_cache` 在失败后同步失效，避免 reload 后 stale 数据复活。
3. SQLite metadata-only 更新能够触发 Codex usage reload。
4. 关键行为全部由 BDD/TDD 用例覆盖。

## BDD 场景
1. `Given existing Codex quota when refresh fails then app invalidates previous success outcome and clears usage cache`
2. `Given persisted usage cache plus sync failure metadata when reloading from disk then stale quota is not restored as success`
3. `Given external metadata-only SQLite update when Codex observation is active then app reloads cached outcomes`

## 实施步骤
1. 先改测试：
   - 更新 `ProviderUsageEngineManualRefreshTests` 中旧的 retain 语义测试。
   - 新增 reload / observation 相关失败测试。
2. 再做最小实现：
   - 调整 Codex 刷新失败分支的 outcome/cache 失效策略。
   - 升级 `CodexSQLiteObservationSnapshot`，让 metadata `updated_at` 级变化进入比较。
   - 让 load/reload 过程中，带 persisted failure 的账号不再恢复 stale cache 为 success。
3. 运行定向测试。
4. 写回 debate 与 memory，并更新 `qmd` 索引。

## 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageEngineManualRefreshTests -only-testing:nolonTests/NolonAccountsViewModelTests`

## 非目标
- 本轮不接入 `CodexHTTPUsageQuery` 的 OAuth token refresh。
- 本轮不重做 explicit `usage_query` fallback 策略。
