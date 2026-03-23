# Codex Token Trend 新增“亿”单位（2026-03-03）

## 目标
- 在 Token Trend 数值展示中新增 `亿` 单位，提升超大 token 数值可读性。

## 范围
- 包含：App 端 Token Trend 汇总/表格紧凑格式、CLI `codex auth usage-trend` summary 文本格式。
- 不包含：JSON 输出字段结构、明细行原始 token 整数值格式。

## 规则
1. 当 token 值 `>= 100,000,000` 时，显示 `%.1f亿`。
2. App 端其余区间保持现有规则：
   - `>= 1,000,000` 显示 `M`
   - `>= 1,000` 显示 `K`
   - `< 1,000` 显示原始整数
3. CLI `usage-trend` summary 保持原先 `m`（百万）规则，但在 `>= 100,000,000` 时切换为 `亿`。

## BDD 验收
1. Given token 值为 `120,000,000`，When 渲染 Token Trend，Then 显示为 `1.2亿`。
2. Given token 值为 `2,500,000`，When 渲染 Token Trend，Then App 显示为 `2.5M`。
3. Given token 值为 `1,500`，When 渲染 Token Trend，Then App 显示为 `1.5K`。
4. Given 执行 `nolon codex auth usage-trend`，When summary.today 为 `120,000,000`，Then 文本包含 `summary.today | 1.2亿`。
