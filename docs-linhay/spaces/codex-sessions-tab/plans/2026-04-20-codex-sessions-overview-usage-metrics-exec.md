# Codex Sessions 概览指标用量展示执行计划（2026-04-20）

## 范围
- 只处理 `Codex Sessions` overview card 的 metric usage 次级信息。
- 不改 row usage 采集链路，不改 section 组头 usage 布局，不新增新的统计卡片。

## BDD
1. Given overview card 处于紧凑态
   When 会话 usage 已部分或全部回填
   Then `Total / Groups / Needs Attention` 显示 count 主值与 usage 次级文案。

2. Given overview card 处于诊断态
   When 渲染 metrics
   Then `Rewritable` 也显示 usage 次级文案。

3. Given 页面排序模式为 `recent`
   When usage 在后台回填完成
   Then overview usage 会更新
   And section / row 顺序仍保持 `recent`。

## 执行步骤
1. 先补 feature 规格，明确 overview usage 的展示形态与动态聚合约束。
2. 先补红灯测试：
   - `CodexSessionsOverviewDataBuilderTests` 锁定 metric 次级文案输出
   - `CodexSessionsTabViewModelTests` 锁定不同 bucket 的 overview usage 聚合
3. 最小实现：
   - `CodexSessionsMetricData` 新增 `detailText`
   - overview builder context 接入 `total/group/rewritable/needsAttention` usage
   - overview usage 聚合改为直接遍历 bucket 内 session，并动态读取 `usageBySessionID`
   - overview card metric UI 渲染 usage 次级文案
4. 定向验证：
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsOverviewDataBuilderTests -only-testing:nolonTests/CodexSessionsTabViewModelTests`
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`

## 风险
- 若 overview usage 继续读取 section 的静态排序字段，`recent` 模式下 usage 回填后不会触发文案更新，指标会长期停在 `Loading…`。
- builder 测试不能硬编码英文 `Usage`，否则在中文本地化环境下会产生伪失败。
