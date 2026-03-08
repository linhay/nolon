# Gemini Quota Usage 接入（2026-03-08）

## 目标
- 为 Gemini Usage 卡片接入 `gemini-cli` 官方 quota 数据。
- 复用现有 ProviderUsage 卡片模型，但允许 Gemini 展示全量模型额度列表。
- 保持 Gemini 非 OAuth 模式现有行为不变。

## 范围
- 包含：Gemini OAuth 账号 quota 拉取、全量 quota bucket 映射、CLI 与 App 共用链路、失败回退。
- 不包含：Gemini API Key 额度、Vertex AI 额度、AI credits、费用统计。

## 约束
1. 不在 Swift 侧重写 Google OAuth / Code Assist onboarding。
2. 通过本机已安装的 `gemini` npm 包内置 `@google/gemini-cli-core` 执行 quota 查询。
3. `GeminiUsageDescriptor` 仅在 `.oauthPersonal` 账号上尝试 quota 拉取。
4. quota 拉取失败时：
   - 不丢失账号身份信息；
   - App 默认仍展示成功卡片，但允许无指标占位；
   - CLI `doctor` 仍能从失败态看到错误。

## 数据映射
1. 使用 `retrieveUserQuota` 返回的 `buckets[]`。
2. `remainingFraction` 转换为 `usedPercent = (1 - remainingFraction) * 100`。
3. `resetTime` 映射到 `RateWindow.resetsAt`。
4. Gemini provider 将每个 bucket 映射为带标题的 usage window，标题默认使用 `modelId`。
5. Gemini 卡片按 CLI quota 返回顺序展示全量模型列表，包括 `flash-lite` / `flash` / `pro` / preview 等 bucket。
6. 为兼容旧消费方，`primary` / `secondary` / `tertiary` 继续保留：
   - `primary` -> 第一条窗口
   - `secondary` -> 第二条窗口
   - `tertiary` -> 第三条窗口

## BDD 验收
1. Given Gemini OAuth 账号已有本地 `.gemini` 凭据，When 刷新 Usage，Then 卡片按 quota bucket 顺序显示全部模型剩余额度与 reset 时间。
2. Given Gemini OAuth quota 查询失败，When 刷新 Usage，Then 页面仍显示账号身份，且指标区域不崩溃。
3. Given Gemini API Key 账号，When 刷新 Usage，Then 保持现有“仅身份快照，无额度指标”行为。
4. Given `nolon gemini auth usage --provider gemini`，When active account 为 OAuth，Then 返回结果包含全量 quota bucket 对应的 usage windows，且兼容字段 `primary/secondary/tertiary` 仍可用。
