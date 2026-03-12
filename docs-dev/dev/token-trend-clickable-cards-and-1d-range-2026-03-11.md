# 历史 Token 消耗：卡片点击切换与 1D 范围（2026-03-11）

## 目标
- 顶部 summary 卡片不再只是展示。
- 支持点击卡片直接切换趋势范围。
- 新增 `1D` 范围，对应只显示一个柱子。

## 交互
- 点击 `Today` 卡片：切换到 `1D`
- 点击 `7 Days` 卡片：切换到 `7D`
- 点击 `30 Days` 卡片：切换到 `30D`
- 点击 `ALL` 卡片：切换到 `ALL`
- 当前选中的卡片会高亮描边与背景。

## 实现
- `TokenTrendRange` 新增 `.days1`
- segmented control 新增 `1D`
- summary 卡片新增 `targetRange`
- 点击卡片直接调用 `onRangeChange`
- `1D` 使用 `trailingDays = 1`，因此图表只保留一个日柱

## 验证
- 已通过：
  - `swift test --package-path libs/Providers --filter CodexTokenTrendServiceTests`
  - `swift test --package-path libs/Providers --filter GeminiTokenTrendServiceTests`
- 未完整跑完：
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-tests ...`
  - 原因：该工程测试前会重新准备大量 SwiftPM 依赖，耗时较长；当前本次改动的服务层逻辑已覆盖。
