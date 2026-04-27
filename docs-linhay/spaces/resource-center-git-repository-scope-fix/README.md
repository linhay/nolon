# 资源中心 Git 仓库展示范围修复（2026-03-18）

## 背景
- 参考：[resource-center-installed-skills-source-2026-03-13](./resource-center-installed-skills-source-2026-03-13.md) 中的“已安装技能补齐”策略。
- 用户反馈：在选择 `github.com` 下某个 Git 仓库（如 `linhay@harmony-next.skills`）时，`Skills` 列表出现“全量本地已安装技能”，而非仅当前仓库目录内容。
- 实际现象：当前仓库技能会出现在前面，但列表被全局已安装技能补齐，造成仓库作用域被污染。

## 目标
- Git / 本地目录仓库：只展示当前仓库查询结果（遵循仓库 `skillsPaths` 作用域）。
- Clawdhub 仓库：保留“已安装技能补齐”能力，避免远端结果缺失时丢失已安装项。

## BDD 验收
1. Given 用户选中 Git 仓库 `linhay@harmony-next.skills`
   And 当前仓库查询结果仅包含 `harmony-next`
   And 全局已安装中额外存在 `global-only`
   When 打开 `Resource Center / Skills`
   Then 列表只显示当前仓库结果，不显示 `global-only`

2. Given 用户选中 Clawdhub 仓库
   And 查询结果不包含某个已安装技能
   When 打开 `Resource Center / Skills`
   Then 仍可通过“已安装补齐”展示该技能

## 实现约束
- `mergeResourceCatalogSkills` 仅在 `repositoryTemplateType == .clawdhub` 时合并 `installedSkills`。
- Git / localFolder / globalSkills 场景不注入 `installedOnly`。
