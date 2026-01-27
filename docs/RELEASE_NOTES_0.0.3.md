# Nolon v0.0.3 Release Notes

## 架构重构与 Git 集成

本版本对项目架构进行了深度优化，并引入了核心的 Git 依赖支持，为后续功能扩展打下坚实基础。

- **MVVM 架构重构**:
  - 为 `SkillProvider` 与列表视图引入了专门的 `ViewModel`，实现 UI 与业务逻辑的进一步解耦。
  - 优化了 `ProviderSidebarViewModel` 的职责划分，集成了 Provider 添加与状态管理。
- **Git 核心支持**:
  - 引入 `SwiftGit` 依赖，增强了应用对 Git 仓库的底层控制能力。
  - 支持将 Provider 路径明确拆分为 `skills` 与 `workflows` 子目录。
- **存储优化**:
  - 将 Provider 的存储方式迁移至专用 JSON 文件，提升了配置持久化的可靠性与灵活性。
- **功能增强**:
  - 实现了从 GitHub 仓库及本地文件夹直接安装本地技能的功能。
  - 远程技能浏览器新增了全局搜索功能，提升了 Skill 的检索效率。
