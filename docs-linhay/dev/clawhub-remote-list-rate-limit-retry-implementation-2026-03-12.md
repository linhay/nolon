# Clawhub 远程列表 429 限流重试：实现说明（2026-03-12）

## 设计
- 位置：`libs/Providers/Sources/ProviderCatalog/SkillsRepositoryFacade.swift`
- 调整点：`performListRemoteResourcesRequest(...)`
- 策略：
  - 仅对 HTTP `429` 做同 URL、同 host 重试。
  - 最大尝试次数为 3 次（首次请求 + 2 次重试）。
  - 优先读取 `Retry-After`，并沿用现有 `rateLimitRetryDelaySeconds(from:)` 的 1...30 秒裁剪逻辑。
  - 其他错误与非 2xx 状态维持原语义。

## 原因
- 下载链路 `performDownloadRemoteResourceRequest(...)` 已有成熟的 429 重试逻辑。
- 列表链路此前缺失这一层保护，导致瞬时限流直接泄漏为 `commandFailed("Remote list failed with status 429")`。
- 两条链路统一后，资源中心远程浏览的稳定性与行为预期更一致。

## 测试
- 新增 `SkillsRepositoryFacadeTests`
  - `list remote resources retries once on same host after 429`
  - `list remote resources returns 429 after same-host retry exhaustion`
- 已运行：
  - `swift test --package-path libs/Providers --filter SkillsRepositoryFacadeTests`
