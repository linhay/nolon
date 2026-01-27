# Nolon v0.0.4 Release Notes

## UI 组件化与技能管理增强

本版本专注于 UI 细节的打磨和技能管理功能的精细化，提升了用户的日常操作体验。

- **UI 组件化重构**:
  - 推出了全新的 `SkillCardView` 和 `WorkflowCardView` 模块，使技能与工作流的展示更加规范、统一。
  - 重构了 `ProviderSidebarView`，使侧边栏的交互更加流畅。
  - 引入了 `ProviderContentTabView` 和 `ProviderDetailGridView`，大幅提升了内容导航的层级感。
- **功能亮点**:
  - **搜索高亮**: 在 Provider 详情页中为 Skill、Workflow 及 MCP 实现了实时搜索与匹配内容高亮。
  - **孤立状态识别**: 核心引擎现在能识别并标记由于路径变更或其他原因导致的“孤立技能”，并提供针对性的管理操作。
  - **图标系统**: 为 Provider 详情页引入了更丰富的 Logo 展示逻辑。
- **维护**:
  - 持续优化了翻译管理脚本。
  - 修复了若干 UI 布局下的小问题。
