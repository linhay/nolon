# 主站 Flowdown 风格设计系统说明（2026-03-04）

## 目标
为 `docs/` 主站建立可持续的 landing 视觉基线，避免后续迭代回到高密度卡片堆叠。

## 结构策略
1. 信息架构固定为：`hero -> trust-strip -> quick-start -> console -> resource-center -> capabilities -> architecture -> ecosystem -> download -> faq`
2. `providers/codex/plugins` 旧锚点保留兼容占位，导航迁移到 `#capabilities`。

## Token 规则
1. 字体：`Space Grotesk`（标题）+ `Instrument Sans`（正文）。
2. 颜色：
   - 背景：`#f5f8fc`
   - 主文本：`#10233f`
   - 品牌色：`#0f766e`
   - 线框：`#d8e2ef`
3. 间距：section 主内边距 28px，移动端 22px。
4. 圆角：卡片 14px，区块 20px。
5. 动效：180ms，仅颜色与位移，禁用布局抖动型动画。

## 可访问性规则
1. 交互元素最小高度 44px。
2. 所有可点击元素提供可见 focus ring。
3. 支持 `prefers-reduced-motion`。
4. 正文最大行长控制在 65-75 字符。

## 导航与兼容
1. 主导航只保留核心区块，减少首屏噪音。
2. 移动端使用折叠菜单（`body.nav-open`）。
3. 兼容旧外链：保留 `id="providers"`, `id="codex"`, `id="plugins"`。

## 文案约束
1. 首屏采用结果导向句式，避免大段实现细节。
2. 中英文 key 必须一一对应，页面不得出现未翻译 key。
3. ecosystem 区块必须明确“衍生项目”定位。
