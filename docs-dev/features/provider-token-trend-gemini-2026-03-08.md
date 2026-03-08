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

## BDD 验收
1. Given Codex Usage 页面存在历史 token 视图，When 重构为通用组件后，Then 现有文案、图表、排序和刷新行为保持不变。
2. Given Gemini 全局 `~/.gemini` 下存在多个 session JSON，When 打开 Gemini Usage 页面，Then 显示历史 token 视图并按日聚合 input/output/cache/total。
3. Given Gemini session JSON 中部分消息没有 `tokens`，When 聚合历史 token，Then 忽略这些消息且不报错。
4. Given Gemini 没有活跃账号或没有 session 文件，When 打开 Gemini Usage 页面，Then 不崩溃，并显示空状态或无数据提示。
5. Given 运行 `nolon gemini auth usage --provider gemini`，When CLI 返回 usage 结果，Then JSON 中包含 `token_trend` 字段，文本模式包含 `token_trend:` 摘要行。
6. Given Gemini Usage 页面已切换到 `7D`，When 刷新历史 token，Then view model 用 `trailingDays = 7` 重新拉取并发布新的趋势快照。
7. Given Nolon 管理的 Gemini runtime home 中存在或不存在 session 文件，When 打开 Gemini Usage 页面，Then 历史 token 仅来源于全局 `~/.gemini`。
