# Codex Usage Token Trend Workspace UI 收敛（2026-04-23）

## 背景
- 用户连续多轮反馈 `Codex -> Usage` 里的 token trend 区域在视觉和交互上都不够稳定：
  - 上半区 `Daily Trend` / `Intraday Drilldown` 被拆成两个 block，切换日级与分钟级时视线来回跳。
  - 图区下方表格有独立滚动和固定高度，核对长表时会出现“里面滚一层，外面再滚一层”的割裂感。
  - 日级柱体偏细，30 天视图下可读性不足。
  - 用户需要一个更直观的曲线模式来快速看总量走势，但不想每次都重新切换。

## 目标
1. 把 `Daily Trend / Intraday Drilldown` 收敛为同一个工作区，减少视觉切换成本。
2. 图区 sticky，表格跟随整页滚动，避免嵌套滚动。
3. 日级图支持 `Bars / Line` 两种模式，`Line` 只看 `total`，并记住选择。
4. 点击单日后自动切到 `Intraday Drilldown`，让钻取动作更直接。

## 设计

### 1. 单一 Trend Workspace
- `summary cards` 继续放在 token trend 顶部。
- summary 下方只保留一个 `Trend Workspace`。
- workspace 顶部使用 segmented control：
  - `Daily Trend`
  - `Intraday Drilldown`
- `Intraday Drilldown` 仍只在支持 intraday 的 provider 中展示。

### 2. sticky 图区
- `Trend Workspace` 内部使用单 section 的 sticky header：
  - header 承载当前 tab 的标题、辅助信息、控制项和图表。
  - section body 承载对应表格。
- sticky 目标是“图区固定、表格继续滚”，不是整个 token trend 卡片全量吸顶。
- 表格移除内部 `ScrollView + maxHeight`，让滚动统一回到页面级 `ScrollView`。

### 3. 日级图模式
- `Bars`
  - 继续展示 `input / output / cache` stacked bar。
  - 通过放大 slot width + bar width 解决柱体过细的问题。
- `Line`
  - 只展示 `total` 折线与面积填充。
  - 保留逐日点位选择能力，用于切 intraday。
- `chartStyle` 以 provider 维度写入本地偏好，默认 `bar`。

### 4. 钻取切换
- 用户点击 `Daily Trend` 中的某一天：
  - 保持既有 `selectedDay` 更新逻辑。
  - 同时把 `activeContentTab` 切换成 `intraday`。
- 用户取消选中日或当前已无有效 `selectedDay`：
  - `activeContentTab` 回退到 `daily`。

## 实现边界
- `libs/NolonUIFoundation`
  - 承载 `chartStyle / contentTab / supportsIntradayDrilldown` 这类通用展示模型。
- `libs/NolonUI`
  - 负责单一 workspace、sticky header、曲线/柱图切换、表格取消内滚动。
- `nolon` app 层
  - 负责 provider 级偏好持久化、tab 自动切换和模型映射。

## 验证
- `ProviderTokenTrendModelsTests`
- `ProviderTokenTrendSectionViewTests`
- `ProviderTokenTrendViewModelParityTests`
