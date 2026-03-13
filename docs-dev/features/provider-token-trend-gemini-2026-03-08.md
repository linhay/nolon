# Provider Token Trend 通用化与 Gemini 接入（2026-03-08）

## 目标
- 将 Codex 历史 token 消耗视图抽成通用组件，供多个 provider 复用。
- 为 Gemini 接入历史 token 消耗展示，数据来源为本地 session 记录中的 token usage。

## 范围
- 包含：通用 token trend 数据模型、通用 SwiftUI 组件、Codex 兼容迁移、Gemini session token 聚合与展示。
- 不包含：Gemini quota 百分比逻辑重写、Gemini 费用统计、跨账号合并展示。

## 数据来源
1. Codex：继续使用现有 `CostUsageFetcher().loadTokenSnapshot(...)` 聚合结果。
2. Gemini：仅扫描全局 `~/.gemini` 的 session JSON 文件，读取 Gemini message 上记录的 token summary。
3. Gemini session 文件格式参考上游 `gemini-cli` 的 `ChatRecordingService`：
   - 路径模式：`~/.gemini/tmp/**/chats/session-*.json`
   - 每条 `type == "gemini"` 消息可能含 `tokens`
   - `tokens` 字段包含：`input` / `output` / `cached` / `thoughts` / `tool` / `total`

## 规则
1. 通用 token trend 组件以 provider-agnostic 的 `TokenTrendSnapshot/Point` 渲染，不依赖 Codex 专用命名。
2. Gemini 历史 token 统计按消息时间戳聚合到日维度：
   - `date` = `YYYY-MM-DD`
   - `inputTokens` = 当日 `tokens.input` 累加
   - `outputTokens` = 当日 `tokens.output` 累加
   - `cacheReadTokens` = 当日 `tokens.cached` 累加
   - `totalTokens` = 当日 `tokens.total` 累加
3. 仅统计 `type == "gemini"` 且存在 `tokens` 的消息。
4. 默认展示当前活跃账号对应的全局 Gemini session 历史；Nolon runtime home 不参与历史 token 聚合，仍不跨账号合并。
5. 视图层保留现有交互：
   - 7D / 30D / ALL 切换
   - 柱状图点选高亮
   - 表格排序
   - 手动刷新
6. 历史 token 消耗 section 需要具备独立调试定位语义：
   - 组件本身遵守 `DebugPageLocatable`
   - Page Marker 路径包含 `provider / usage / 历史 Token 消耗`
   - 调试按钮继续悬浮，不额外占用布局高度
7. section 内部可交互子块也需要细分定位：
   - 摘要卡片路径追加卡片标题
   - 图表区路径追加 `Daily Trend`
   - 表格区路径追加 `Daily Breakdown`
8. section 处于 loading 时，骨架屏需要覆盖摘要卡、图表和表格三个区域，避免卡片下半区跳空。
9. Gemini Usage 首屏或手动刷新期间，只要账号区仍处于主 loading，历史 token 消耗 section 也要同步显示骨架屏，不能先退回空态。

## BDD 验收
1. Given Codex Usage 页面存在历史 token 视图，When 重构为通用组件后，Then 现有文案、图表、排序和刷新行为保持不变。
2. Given Gemini 全局 `~/.gemini` 下存在多个 session JSON，When 打开 Gemini Usage 页面，Then 显示历史 token 视图并按日聚合 input/output/cache/total。
3. Given Gemini session JSON 中部分消息没有 `tokens`，When 聚合历史 token，Then 忽略这些消息且不报错。
4. Given Gemini 没有活跃账号或没有 session 文件，When 打开 Gemini Usage 页面，Then 不崩溃，并显示空状态或无数据提示。
5. Given 运行 `nolon gemini auth usage --provider gemini`，When CLI 返回 usage 结果，Then JSON 中包含 `token_trend` 字段，文本模式包含 `token_trend:` 摘要行。
6. Given Gemini Usage 页面已切换到 `7D`，When 刷新历史 token，Then view model 用 `trailingDays = 7` 重新拉取并发布新的趋势快照。
7. Given Nolon 管理的 Gemini runtime home 中存在或不存在 session 文件，When 打开 Gemini Usage 页面，Then 历史 token 仅来源于全局 `~/.gemini`。
8. Given 历史 token 消耗 section 开启 Page Marker 调试，When 复制定位信息，Then 文本包含 provider、Usage 页签和“历史 Token 消耗”三级路径。
9. Given 历史 token 消耗 section 内部卡片或图表/表格区域开启 Page Marker 调试，When 复制定位信息，Then 文本会继续包含对应子块标题。
10. Given 历史 token 消耗 section 正在 loading，When 页面渲染骨架屏，Then 摘要卡、图表区和表格行都会显示稳定数量的占位骨架。
11. Given Gemini CLI 用量页正在首屏加载或刷新账号信息，When 账号卡仍显示 loading，Then 历史 token 消耗 section 也同步显示骨架屏，直到拿到趋势数据或错误。
