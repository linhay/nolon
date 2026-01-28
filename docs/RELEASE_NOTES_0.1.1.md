# Nolon v0.2.0 Release Notes

## 🎯 重大架构重构

### 统一资源管理系统
- **Repository 协议架构**: 引入全新的 `RemoteResourceRepository` 协议，统一管理 Skills、Workflows 和 MCPs 三类资源
- **四大 Repository 实现**:
  - `ClawdhubRepository`: API 驱动的云端资源仓库，支持所有三类资源的浏览与下载
  - `GitRepository`: 基于 SwiftGit 的 Git 仓库集成，支持 SSH/HTTPS 认证，自动同步与浅克隆
  - `LocalFolderRepository`: 本地文件系统扫描器，递归发现本地资源
  - `GlobalCacheRepository`: 全局缓存管理器（`~/.nolon/`），同时作为本地资源仓库使用

### 资源独立化与路径重构
- **Workflow 完全独立**: 
  - 从 Skill 关联中解耦，成为一等公民资源类型
  - 移除了基于 Skill 自动生成 workflow 的逻辑
  - 独立缓存路径：`~/.nolon/workflows`
- **MCP 全面支持**:
  - 新增 MCP 全局缓存：`~/.nolon/mcps`
  - 智能配置合并至 Provider 的 `mcp_settings.json`
  - 支持从 Clawdhub、Git 仓库、本地缓存安装
- **Skills 路径优化**: 
  - 全局缓存保持在 `~/.nolon/skills`
  - 支持软链接和复制两种安装方式

### 统一安装器
- **ResourceInstaller**: 取代旧的 `SkillInstaller`，提供统一的资源安装接口
  - `installFromRemote()`: 完整的下载 → 缓存 → 安装流程
  - `installFromCache()`: 从全局缓存快速安装
  - `uninstall()`: 可选的缓存清理
  - 自动处理 zip 解压、文件复制、软链接创建
  - MCP 配置自动合并到 Provider 配置文件

## 🔧 技术优化

### Swift 6 严格并发
- 全面适配 Swift 6 actor isolation 模型
- `GlobalCacheRepository` 和 `ResourceInstaller` 使用 actor 确保线程安全
- `RemoteResourceRepository` 协议标记为 `Sendable`
- 正确使用 `nonisolated` 标注不可变属性

### Clean Architecture
- **Models**: 纯 Swift 结构体，不可变，Codable & Sendable
- **Infrastructure**: 副作用隔离（文件操作、网络请求、Git 同步）
- **Views**: SwiftUI 视图层，通过 Repository 协议与基础设施通信
- 依赖方向：Views → Infrastructure → Models

### 错误处理优化
- 统一的 `RepositoryError` 枚举覆盖所有错误场景
- 本地化错误消息
- 明确区分资源类型不支持、网络错误、文件操作失败等场景

## 📦 功能增强

### 远程资源浏览器
- **三类资源统一浏览**: Skills、Workflows、MCPs 在同一界面切换
- **多仓库支持**: 
  - Clawdhub 官方仓库
  - GitHub/GitLab 等 Git 仓库（自动同步）
  - 本地文件夹
  - 全局缓存（已下载资源）
- **智能过滤与搜索**: 支持按名称、描述搜索，Repository 层级查询过滤

### 安装流程优化
- **Workflow 安装**: 直接安装到 Provider 的 workflow 目录
- **MCP 安装**: 
  - 自动检测 Provider 的 MCP 配置路径（通过 ProviderTemplate）
  - 智能合并 `command`、`args`、`env` 配置
  - 保持现有配置不被覆盖
- **Skills 安装**: 保持原有安装逻辑，但代码更清晰

### 缓存管理
- **自动缓存**: 所有远程下载的资源自动缓存到 `~/.nolon/`
- **重复检测**: 安装时智能检查缓存，避免重复下载
- **缓存浏览**: GlobalCacheRepository 可作为资源仓库直接浏览已缓存内容
- **选择性清理**: 卸载时可选择是否同时删除缓存

## 🐛 Bug 修复

- 修复了 `RemoteMCP.MCPConfiguration` 缺少 `Encodable` 协议导致的编码错误
- 修复了 Actor isolation 导致的并发访问错误
- 修复了 `Provider.defaultMcpConfigPath` 属性不存在的问题（应使用 `ProviderTemplate`）
- 修复了 `RemoteSkillsBrowserView` 参数顺序错误
- 修复了 Workflow 和 MCP 安装按钮无响应的问题
- 修复了 GlobalSkills 仓库错误使用 LocalFolderRepository 的问题
- 修复了从 Git/本地仓库安装 Workflow 无法更新卡片安装状态的问题（现在会跟随 Provider 的 workflow 目录刷新）
- 修复了 Remote 仓库列表排序与删除索引错位问题（全局仓库固定置顶）
- 修复了从仓库安装 Skill 后 Provider Skills 页面可能出现 “未能打开文件，因为它不存在” 的问题
- 修复了 Provider Tab 数字（尤其是 MCP）不刷新/不准确的问题，并支持 Codex 的 `config.toml` 解析统计

## 📝 代码改进

### 新增文件（6个核心基础设施）
- `RemoteResourceRepository.swift` (178 行): 核心协议定义
- `ClawdhubRepository.swift` (566 行): Clawdhub API 客户端
- `LocalFolderRepository.swift` (390 行): 本地文件扫描器
- `GitRepository.swift` (317 行): SwiftGit 集成
- `GlobalCacheRepository.swift` (380 行): 全局缓存管理 + Repository 实现
- `ResourceInstaller.swift` (357 行): 统一资源安装器

### 修改文件
- `NolonManager.swift`: 新增 `mcpsURL` 属性
- `RemoteSkillsGridView.swift`: 适配新 Repository 架构
- `RemoteMCP.swift`: `MCPConfiguration` 改为 `Codable`
- `MainSplitView.swift`: 新增 Workflow 和 MCP 安装回调处理

## ⚠️ 破坏性变更

- 移除了 `ClawdhubService` （替换为 `ClawdhubRepository`）
- 移除了 `LocalFolderService` （替换为 `LocalFolderRepository`）
- 移除了 `GitHubRepositoryService` （替换为 `GitRepository`）
- `GlobalCacheRepository` 不再自动为 Skills 生成 global workflows
- Workflow 现在完全独立，不再与 Skill 关联

## 🎓 开发者注意事项

- 所有 Repository 实现必须遵守 `RemoteResourceRepository` 协议
- 使用 `ResourceInstaller` 替代直接文件操作进行资源安装
- MCP 安装需要通过 `ProviderTemplate` 获取配置路径，而非 `Provider` 实例
- Git 操作使用 SwiftGit 库，支持浅克隆（`depth=1`）以节省空间

## 📊 统计数据

- 新增代码：约 2600 行
- 重构代码：约 200 行
- 修复 Bug：7 个编译错误 + 2 个运行时 bug
- 架构模式：Clean Architecture + Repository Pattern
- 并发模型：Swift 6 Actor Isolation

---

# Nolon v0.1.1 Release Notes

## 核心改进与修复

- **卡片组件重构与体验升级**: 
  - **Skill, MCP, Workflow 视觉统合**: 统一了三类卡片的 UI 规范，采用 16pt 内边距与 12pt 元素间距，视觉风格高度一致。
  - **操作收纳与极简设计**: 移除了卡片底部冗余的编辑/删除按钮，将功能统一收纳至右上角更多菜单与右键上下文菜单中。
  - **交互安全性增强**: 为所有删除和卸载操作增加了二次确认弹窗（Confirmation Dialog），有效防止误触风险。

- **Workflow 管理增强**:
  - **MCP 工作流同步**: 实现了 MCP 关联工作流自动同步至 Provider 工作目录（如 `.gemini/workflows` 等）的功能，确保 IDE 即刻识别。
  - **智能来源标注**: `WorkflowCardView` 现在能根据物理路径自动标注 `Skill` / `User` / `MCP` 来源，解析逻辑已适配软链接情形。

- **国际化与体验细节**:
  - **本地化优化**: 修正了部分中文翻译，确保技术术语（如 MCP, Workflow）在多语言环境下的一致性。
  - **动画反馈**: 优化了卡片点击与交互的响应速度，提升了操作流畅度。

- **链接解析与导入优化**:
  - **URL Scheme 增强**: 完善了 `nln://` 与 `nolon://` 协议的解析能力，现在支持从包含协议头的完整 URL 中自动提取 Git 仓库地址及子路径。
  - **单实例窗口管理**: 修复了点击外部链接时可能产生重复窗口的问题，确保应用始终在单一窗口内处理导入事件。
  - **状态同步修复**: 解决了 `@State` 缓存导致的导入界面无法即时更新 URL 的问题，提升了从外部一键安装 Skill 的成功率。

- **开发者设施**:
  - **代码鲁棒性**: 修复了公共模块中关于 Swift 访问控制（Access Control）的潜在编译报错。
  - **项目自动化**: 引入了更严谨的 UI 开发规范与编码 Skill 沉淀。
