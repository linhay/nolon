# Skill: gettokens-doc-writeback

用于本仓库的文档与记忆写回闭环，确保沉淀后的内容可检索、可追踪、可回查。

## trigger
- 更新 `docs-linhay/dev/`、`docs-linhay/memory/`。
- 会话沉淀、关键决策写回、里程碑登记。
- 需要执行 `qmd update` / `qmd embed`。

## workflow
1. 先判断落位
   - 技术方案、治理说明、实现边界：`docs-linhay/dev/`
   - 决策、行动项、偏好变化、里程碑、风险：`docs-linhay/memory/YYYY-MM-DD.md`
2. 写回要求
   - 记忆写回只追加高价值、可复用、可回查的信息。
   - 同一轮若同时有治理说明和决策结论，`dev/` 与 `memory/` 都要更新。
3. 检索同步
   - 执行 `qmd update`
   - 执行 `qmd embed`
4. 失败处理
   - 若 `qmd` 失败，要在收尾说明失败命令、影响范围、是否已写入文件但暂不可检索。

## do
- 把“已发生的关键决策”写成可搜索文本，而不是口头描述。
- 优先保持文件名可追踪，必要时带日期。

## dont
- 不要只改 `memory` 不跑 `qmd`。
- 不要把技术设计细节塞进 `memory` 替代 `dev/`。

## validation
- `docs-linhay/dev/` 与 `docs-linhay/memory/` 的新增内容都能从 `git diff` 中清晰定位。
- `qmd update` 与 `qmd embed` 已执行。
