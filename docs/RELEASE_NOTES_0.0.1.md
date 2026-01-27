# Nolon v0.0.1 Release Notes

## 核心功能上线

这是 nolon 的第一个正式版本，致力于打造一个简单、高效的 AI Coding Agent 技能管理工具。

- **基础架构搭建**: 建立了基于 SwiftUI 的多栏设计界面，提供直观的 Provider 与 Skill 管理体验。
- **远程技能浏览**: 引入了 `Clawdhub` 市场，支持从远程配置库中发现、预览和安装技能。
- **Provider 系统**: 初步实现了 Provider 与 Provider Template 模型，规范化了技能来源的管理逻辑。
- **本地化初步支持**: 引入了初步的多语言翻译支持。
- **核心组件**:
  - `MainSplitView`: 全局导航基础。
  - `SkillDetailView`: 技能详情展示与操作。
  - `ProviderSidebar`: 侧边栏 Provider 切换与状态展示。
