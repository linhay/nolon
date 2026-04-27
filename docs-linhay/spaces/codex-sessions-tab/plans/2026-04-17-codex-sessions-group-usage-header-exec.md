# Codex Sessions 组头用量展示执行计划（2026-04-17）

## 范围
- 只处理 `Codex Sessions` section header 的组级 usage 展示。
- 不改 row 级 usage 采集链路，不改刷新策略，不改会话详情展开交互。

## 执行步骤
1. 先补 feature 规格，锁定“组头显示当组用量”的行为与状态规则。
2. 先补测试：
   - builder 单测锁定 section usage 聚合
   - snapshot 测试锁定 header 视觉位置
3. 最小实现：
   - `CodexSessionsSectionData` 新增 `usage`
   - builder 聚合 row usageState
   - UI 在 section header 顶部渲染 usage
4. 定向验证：
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests`
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`

## 风险
- `UnifiedCodexSessionViews.swift` 当前已有未提交改动，必须只做局部插入，不能覆盖现有 inline detail 与 compact row 行为。
- `CodexSessionsSectionData` 加字段后，所有手写 `.init(...)` 调用点都要同步补齐，避免编译失败。
