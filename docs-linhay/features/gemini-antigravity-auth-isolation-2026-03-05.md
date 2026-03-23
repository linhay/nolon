# Gemini / Antigravity 账号与用量强隔离（2026-03-05）

## 背景
本期目标是将 Gemini 与 Antigravity 从“同家族”语义调整为“强隔离 provider”。

## 需求
1. CLI 命令统一采用 `nolon gemini auth <action>`。
2. `--provider` 必填，仅允许 `gemini|antigravity`。
3. 禁止兼容旧命令 `nolon gemini usage ...`。
4. 账号、活跃账号、用量读取范围按 provider 严格隔离。

## 验收标准
1. `nolon gemini auth usage --provider gemini` 成功，`command` 为 `gemini.auth.usage`。
2. `nolon gemini auth usage`（无 `--provider`）失败，并提示缺少 provider。
3. `nolon gemini auth doctor --provider antigravity` 成功，`command` 为 `gemini.auth.doctor`。
4. Gemini 与 Antigravity 的账号列表、活跃账号互不影响。
5. App Usage Tab 在默认 `auto` 模式下，不再因为缺少 probe 环境变量展示 `unsupported` 错误卡片。

## 变更范围
- `libs/Providers/Sources/NolonCoreCLIKit` 的命令定义、参数解析、Runner 执行路径。
- `libs/Providers/Tests/ProvidersTests/NolonCoreCLIKitTests.swift` 的 Gemini 命令测试。
- `libs/Providers/Sources/ProviderUsage/Descriptors/GeminiUsageDescriptor.swift` 的 auto 模式 fallback 策略。
- `nolon/Skills/Views/Provider/Usage/ProviderUsageSnapshotView.swift` 的“成功但无指标”占位文案。
- `nolon/Skills/Views/Provider/Usage/ProviderUsageView.swift` 的非 codex 登录入口策略（Gemini/Antigravity 优先 Refresh，不显示 Sign in）。
