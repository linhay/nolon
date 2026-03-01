# Codex Config.toml 一期技术方案（SDK 先行）

## 实施顺序
1. SDK：扩展 `CodexConfigToml`（解析模型 + 单测）。
2. App：`CodexAdvancedConfigView` 新增配置区（结构化 + 原文兜底）。

## SDK 设计
- 位置：`libs/Providers/Sources/Providers/Codex/CodexGeneratedFiles.swift`
- 目标：对齐官方文档和源码字段，重点补齐：
  - `[features]`（含 `multi_agent`）。
  - common options（如 `approval_policy`、`sandbox_mode`、`web_search`、`model_reasoning_effort`、`model_verbosity`、`personality` 等）。
  - `[agents]` 以及动态 role 表（`agents.<role>`）。
- 测试：在 `CodexGeneratedFilesParserTests` 增加复杂 TOML 用例，验证解析覆盖。

## App 设计
- 位置：`nolon/Skills/Views/Provider/CodexAdvancedConfigView.swift`
- 结构：
  - 文档区：展示官方文档入口，支持锚点跳转。
  - features 区：展示并可修改 feature flag（一期重点 `multi_agent`）。
  - common options 区：可编辑常用配置字段。
  - multi-agent roles 区：编辑 `agents.max_threads` / `agents.max_depth` / role 列表。
  - TOML 兜底区：打开原文编辑器进行完整配置。
- 持久化策略：
  - 结构化编辑优先走 SDK 模型保存。
  - 复杂/未覆盖项通过 TOML 兜底编辑保证完整能力。

## 风险与约束
- Codex 上游配置字段演进较快；字段定义以官方文档 + 本地 `reference-projects/codex` 同步校验。
- 结构化编辑难以覆盖所有未来字段，一期通过 TOML 兜底确保不阻塞。
