# 会话“整理”正式沉淀治理说明

日期：2026-04-27

## 背景

当前仓库已经在 `AGENTS.md` 中声明“优先新增或更新项目级 skills，再视情况上升到 AGENTS”，但缺少一条明确能力：当用户说“整理”时，agent 应执行正式沉淀流程，而不是只做普通总结。

同时，`AGENTS.md` 已引用：
- `gettokens-space-governance`
- `gettokens-doc-writeback`
- `gettokens-agents-governance-sync`

这些项目级 skills 之前并不存在，导致治理入口与执行载体脱节。

## 目标

为本仓库建立与 GetTokens 对齐的“整理”语义：
1. “整理”默认触发一次正式的会话沉淀流程。
2. 流程先提炼可复用模式，再判断落位到 `skill`、`docs`、`memory` 或 `AGENTS.md`。
3. 只有 `repo-wide` 且长期稳定的规则才允许上升到 `AGENTS.md`。
4. 写回后必须执行 `qmd update` 与 `qmd embed`，保证可检索。

## 治理分层

### 1. `gettokens-session-organize`

统一定义“整理”的触发条件、落位判断、验证动作，是正式沉淀的总入口。

### 2. supporting skills

- `gettokens-space-governance`
  - 负责 `space` 创建、命名、README、截图、debate 归档。
- `gettokens-doc-writeback`
  - 负责 `docs-linhay/dev/`、`docs-linhay/memory/` 写回与 `qmd` 同步。
- `gettokens-agents-governance-sync`
  - 负责判断规则是否足够稳定，是否应提升到 `AGENTS.md`。

## 落位规则

1. 仅当前任务或单模块复用的流程，优先沉淀为项目级 `skill`。
2. 需要长期查阅的技术说明或治理边界，写入 `docs-linhay/dev/`。
3. 关键决策、行动项、风险结论、里程碑，写入 `docs-linhay/memory/YYYY-MM-DD.md`。
4. 只有跨模块、跨任务、长期稳定的 repo-wide 规则，才写入 `AGENTS.md`。

## 验证闭环

每次执行正式沉淀流程后，至少完成：
1. `bash docs-linhay/scripts/check-docs.sh`
2. `git diff --check`
3. `qmd update`
4. `qmd embed`

其中第 1 条额外负责校验 `AGENTS.md` 中引用的关键 `gettokens-*` skills 文件是否实际存在。

## 本次落地内容

1. 新增 `gettokens-session-organize` 作为“整理”总入口。
2. 补齐 `AGENTS.md` 已引用的 3 个项目级 skills。
3. 更新 `AGENTS.md`，把“整理=正式沉淀流程”提升为 repo-wide 规则。
4. 扩展 `docs-linhay/scripts/check-docs.sh`，校验关键项目级 skills 是否存在。
