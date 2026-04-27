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
4. Gemini provider 将每个 bucket 映射为带标题的 usage window，标题默认使用规范化后的 `modelId`：
   - `gemini-3.1-pro-preview-customtools` 统一展示为 `gemini-3.1-pro-preview`
   - `*-001` 后缀在展示层移除（如 `gemini-2.5-flash-001` -> `gemini-2.5-flash`）
5. Gemini 卡片不再依赖 CLI quota 原始返回顺序，而是按稳定优先级展示全量模型列表：
   - `3.1 pro preview` -> `3 pro preview` -> `2.5 pro` -> `3 flash preview` -> `2.5 flash` -> `2.0 flash` -> `2.5 flash-lite`
   - 未知新模型排在已知模型之后，并按标题字典序稳定展示
   - 若多个 bucket 规范化后落到同一展示标题，仅保留排序更靠前的一项，避免重复额度行
6. 为兼容旧消费方，`primary` / `secondary` / `tertiary` 继续保留：
   - `primary` -> 第一条窗口
   - `secondary` -> 第二条窗口
   - `tertiary` -> 第三条窗口

## UI 组件化
1. quota 展示区已抽成通用 `ProviderQuotaSection`。
2. Codex 紧凑卡片与 Provider Usage 快照卡片共用同一套窗口解析逻辑：
   - 优先渲染 `UsageSnapshot.windows`
   - 若为空，则回退 `primary / secondary / tertiary`
3. 组件支持两种样式：
   - `compact`：用于账号列表卡片
   - `detailed`：用于 Usage 快照卡片
4. 这样 Gemini 全量模型窗口和 Codex 旧式窗口都走同一套展示入口。
5. 共用 quota 组件时必须保留 Codex 既有展示语义：
   - `usage.metric.resets_at` 本地化 key 不得移除；
   - credits 区需要区分“余额刷新时间”和“credits 快照时间”，不能只保留一个时间点。
6. Codex 多账号 auth 目录在 rename / 临时文件切换期间：
   - 目录重载不得因瞬时消失的 snapshot 文件崩溃；
   - 临时文件（如 `.dat.nosync*`）不得污染账号列表；
   - 卡片刷新中的 UI 状态最终必须回落为成功或失败，不能永久停留在 loading。
7. 切换 provider tab / 页面重新 appear 不得隐式触发 usage 刷新；自动刷新只能由明确的刷新入口、后台 watcher 或定时策略驱动。

## BDD 验收
1. Given Gemini OAuth 账号已有本地 `.gemini` 凭据，When 刷新 Usage，Then 卡片按稳定模型优先级显示全部模型剩余额度与 reset 时间，而不是依赖上游 bucket 原始顺序。
2. Given Gemini OAuth quota 查询失败，When 刷新 Usage，Then 页面仍显示账号身份，且指标区域不崩溃。
3. Given Gemini API Key 账号，When 刷新 Usage，Then 保持现有“仅身份快照，无额度指标”行为。
4. Given `nolon gemini auth usage --provider gemini`，When active account 为 OAuth，Then 返回结果包含全量 quota bucket 对应的 usage windows，且兼容字段 `primary/secondary/tertiary` 仍可用。
5. Given Codex 或 Gemini quota 卡片需要渲染额度窗口，When `UsageSnapshot.windows` 存在时，Then 统一由通用 quota 组件按具名窗口渲染；When `windows` 为空时，Then 回退渲染 `primary/secondary/tertiary`。
6. Given Codex 额度窗口仍通过 `NSLocalizedString("usage.metric.resets_at", ...)` 生成绝对重置时间，When zh-Hans 用户查看卡片，Then 应继续显示中文翻译而不是英文回退。
7. Given provider 单独缓存了 credits 余额刷新时间，When detailed usage 卡片展示 credits，Then 卡片同时展示“刷新于”时间以及底层 credits 快照时间。
8. Given Codex auth 目录在 watcher 重载期间出现 rename 事件和临时文件，When 某个 snapshot 文件恰好已被移走，Then 磁盘重载应忽略该文件而不是崩溃，且剩余账号仍可正常加载。
9. Given 用户只是切换到其他 tab 再切回 Usage，When 页面重新 appear，Then 不应自动触发 Codex 或其他 provider 的 usage 刷新。
10. Given quota buckets 同时返回 `gemini-3.1-pro-preview` 与 `gemini-3.1-pro-preview-customtools`，When 构建 usage windows，Then UI 只展示一条 `gemini-3.1-pro-preview` 额度项。
11. Given quota bucket 的 `modelId` 带有 `-001` 后缀，When 渲染 model 标题，Then UI 应展示去后缀后的标准模型名。
