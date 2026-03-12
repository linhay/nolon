# Skill 详情页统一到 `SkillDetailView`

日期：2026-03-11

## 结论
- `SkillDetailView.swift` 是唯一允许保留的 skill 详情页宿主布局。
- 本地 skill、远程已安装 skill、远程未安装 skill 全部统一到这套两栏布局。
- 不再允许远程 skill 继续维护独立三栏或独立 sheet 风格。

## 实现约束
- `SkillDetailView` 的视觉风格不变：
  - 左侧 sidebar
  - 右侧 content
  - 右上关闭按钮
  - 现有背景、间距、toolbar 样式保持
- 差异只能通过内部组件配置表达，不能再新增一套顶层布局。

## 当前实现
- `SkillDetailViewModel` 统一承接三种模式：
  - `.local`
  - `.remoteInstalled`
  - `.remoteCatalog`
- `SkillDetailSidebar` 改为按模式配置：
  - 远程未安装隐藏资源导航、同步、Finder 按钮
  - 远程已安装显示 local badge，并在 About 区补充本地路径和更新时间
- `SkillDetailContent` 改为按模式切换：
  - `fileBrowser`
  - `remoteOverview`
- `RemoteSkillDetailView` 已降级为 `SkillDetailView` 包装器。

## 验证
- 新增 `SkillDetailViewModelTests`
- 重点验证：
  - 本地 skill 保持文件浏览模式
  - 远程已安装 skill 进入统一文件浏览模式
  - 远程未安装 skill 进入统一 overview 模式
  - 远程 skill 的 provider 安装状态按 slug 解析
