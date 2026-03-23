# 历史 Token 消耗：summary 稳定化与 ALL 卡片（2026-03-11）

## 问题
- `历史 Token 消耗` 的范围切换（`7D / 30D / ALL`）不仅影响图表和表格，也会影响顶部 `Today / 7 Days / 30 Days` 三张 summary 卡片。
- 用户预期：范围切换只改变“展示窗口”，summary 应保持稳定口径；同时需要补一张 `ALL` 卡片展示累计总量。

## 原因
- 之前的 `ProviderTokenTrendSnapshot` 只有：
  - `points`
  - `todayTokens`
  - `last7DaysTokens`
  - `last30DaysTokens`
- `CodexTokenTrendService` / `GeminiTokenTrendService` 会先按当前范围裁剪 `points`，再基于裁剪后的 `points` 计算 summary。
- 结果：切到 `7D` 时，`30 Days` 卡片实际也只在看 `7D` 内的数据，所以数字跟着变。

## 修复
- `points` 仅用于图表/表格展示窗口。
- summary 改为始终基于“全量历史点”计算：
  - `todayTokens`
  - `last7DaysTokens`
  - `last30DaysTokens`
  - `allDaysTokens`（新增）
- 最后再根据选中的范围裁剪 `points`，这样：
  - 图表/表格随范围切换
  - summary 卡片保持稳定
  - 新增 `ALL` 卡片显示累计总量

## 验证
- `swift test --package-path libs/Providers --filter CodexTokenTrendServiceTests`
- `swift test --package-path libs/Providers --filter GeminiTokenTrendServiceTests`
