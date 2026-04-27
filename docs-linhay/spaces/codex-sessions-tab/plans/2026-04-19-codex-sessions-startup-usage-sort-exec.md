# 2026-04-19 Codex Sessions 首屏 Usage 排序修复执行计划

## 目标
1. 修复 cached snapshot 首屏未按 `usage` 排序的问题。
2. 保持现有 recent/usage 排序逻辑与异步 usage 回填链路。
3. 用测试锁定首屏排序语义，避免后续回归。

## BDD 场景

### 场景 1：首屏 cached snapshot 直接按 usage 排序
- Given 偏好排序方式为 `usage`
- And cached snapshot 中包含多个项目和会话
- And usage index 已命中所有关键会话
- When 首屏加载 cached snapshot
- Then section 顺序按聚合 usage 排序
- And 组内 row 顺序按 usage 排序

### 场景 2：recent 模式不受影响
- Given 偏好排序方式为 `recent`
- When usage 在后台补齐
- Then 首屏及后续顺序保持 recent 语义

## TDD 步骤
1. 先新增 cached snapshot + usage index 预热红灯测试。
2. 扩展 ViewModel service 协议与 mock。
3. 在 cached snapshot 应用前预热 usage 状态。
4. 跑定向测试验证 usage/recent 两条排序链路。

## 验证命令
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -derivedDataPath /tmp/nolon-codexsessions-startup-usage-sort -only-testing:nolonTests/CodexSessionsTabViewModelTests`

## 风险控制
- 只改 ViewModel 和对应测试，不改会话存储 schema。
- 不动无关 UI 文件。
- 如果 usage index 预热结果不稳定，优先保证“首屏按偏好排序”，不把 fallback 行为扩散到 recent 模式。
