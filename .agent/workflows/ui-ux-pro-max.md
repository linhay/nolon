---
description: Plan and implement UI using SwiftUI and modern macOS design patterns
---

# UI/UX Pro Max - SwiftUI & macOS 极值设计

这是一个针对 SwiftUI 和 macOS 现代设计规范的 UI/UX 执行工作流。

## 核心设计哲学

1. **Glassmorphism (磨砂玻璃)**: 充分利用 macOS 的 `visualEffect`。
2. **SF Symbols**: 优先使用苹果官方图标库，确保视觉的一致性。
3. **微交互**: 使用 SwiftUI 的 `animation` 和 `transition` 提升用户体验。
4. **SwiftUI 最佳实践**: 采用 `@Observable` 状态管理，保持视图的简洁和高性能。

---

## 如何使用此工作流

当用户请求 UI/UX 相关工作（设计、构建、审查、优化、修复）时，请遵循以下步骤：

### 第一步：需求与审美分析

分析用户的产品类型并确定视觉基调：
- **产品类型**: 工具类、内容类、管理端、还是桌面端小工具？
- **关键词**: 极简 (Minimal)、优雅 (Elegant)、专业 (Professional)、磨砂玻璃 (Glassmorphism)。
- **技术栈**: 默认使用 **SwiftUI**，并遵循 macOS 14.0+ 的最新特征。

### 第二步：设计系统整合

在实现任何界面前，必须查阅项目现有的设计系统：
- **颜色**: 参考 `nolon/DesignSystem/AppColors.swift`。
- **预览**: 参考 `nolon/DesignSystem/ColorSystemPreview.swift`。

### 第三步：SwiftUI 执行规范

1. **响应式布局**: 确保在不同窗口尺寸下的表现（使用 `NavigationSplitView` 或自适应容器）。
2. **状态管理**: 统一使用 `Observation` 框架 (`@Observable`)。
3. **视图解耦**: 每个视图文件尽量控制在 200 行以内，复杂的组件通过 `Extension` 或子视图 (`ViewBuilder`) 拆分。
4. **原生组件优先**: 优先使用 SwiftUI 的原生组件进行封装，而不是从头造轮子。

---

## 现代 UI 专业规范

### 图标与视觉元素

| 规则 | 推荐 (Do) | 反对 (Don't) |
|---|---|---|
| **图标库** | 唯一指定 `Image(systemName:)` 配合 SF Symbols | 使用 Emoji 或 低质量位图图标 |
| **悬停逻辑** | 使用 `.onHover { ... }` 改变外观，确保 `cursor(.pointingHand)` | 没用交互反馈或使用导致布局跳动的缩放 |
| **品牌 Logo** | 使用高质量矢量图 (SVG/PDF) 导入 Assets | 低清 PNG 或手动临摹 |

### macOS 特色交互

| 规则 | 推荐 (Do) | 反对 (Don't) |
|---|---|---|
| **背景模糊** | 使用 `.background(.ultraThinMaterial)` | 使用纯色但不带透明度的背景 |
| **列表风格** | 使用 `.listStyle(.sidebar)` 配合 macOS 原生 Sidebar | 在桌面端模拟移动端的普通列表样式 |
| **动画耗时** | 统一使用 `.spring()` 或 `duration` 在 0.2~0.3s 的动画 | 缺少过渡或动画过于拖沓 (>0.5s) |

---

## 交付前检查清单 (Pre-Delivery Checklist)

- [ ] **视觉一致性**: 所有图标是否都来自 SF Symbols？悬停时是否有交互反馈？
- [ ] **磨砂透明度**: 在 Light/Dark 模式下视觉对比度是否足够？
- [ ] **状态安全**: 是否使用了 `@Observable`？是否避免了不必要的视图重绘？
- [ ] **性能检查**: 进入/退出或窗口缩放时是否有掉帧？
- [ ] **交互闭环**: 点击、悬停、右键菜单（如有）是否都已实现？
- [ ] **辅助功能**: 图片是否有 `accessibilityLabel`？文字对比度是否达标？
