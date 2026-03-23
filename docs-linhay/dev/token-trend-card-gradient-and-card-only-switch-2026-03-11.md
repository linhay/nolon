# 历史 Token 消耗卡片交互优化（2026-03-11）

## 背景
- 用户要求把范围切换进一步收敛到 summary 卡片本身：
  1. 卡片增加渐变底色
  2. 点击区域覆盖整张卡片
  3. 移除上方 segmented control

## 实现
- `nolon/Skills/Views/Provider/Usage/ProviderTokenTrendSection.swift`
  - 移除 header 内的 range `Picker`，顶部只保留刷新操作。
  - summary 卡片改为卡片自身承载背景与描边，点击热区覆盖整张卡片。
  - 卡片底色改为基于各自语义色的 `LinearGradient`，选中态和未选中态使用不同透明度。
  - 增加可测试的 UI 契约：
    - `quickActionRanges`
    - `usesHeaderRangePicker`
    - `usesFullCardTapTarget`
    - `summaryCardMinHeight`

## 验证
- 通过：
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -derivedDataPath /tmp/nolon-token-trend-ui-polish test -only-testing:nolonTests/CodexUsageTabPresentationTests -only-testing:nolonTests/ProviderUsageSkeletonPolicyTests`

## 结果
- 范围切换入口统一为 `Today / 7D / 30D / ALL` 四张卡片。
- 不再出现“上方 segment 和下方卡片是两套控件”的交互分裂。
- 选中态更明显，且整卡都可点。
