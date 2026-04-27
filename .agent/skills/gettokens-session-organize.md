# Skill: gettokens-session-organize

用于在本仓库中把用户说的“整理”视为一次正式会话沉淀流程，而不是普通总结。

## trigger
- 用户明确说“整理”“帮我整理一下”“做一次沉淀”“把这轮会话沉淀下来”。
- 阶段性任务完成后，用户要求把本轮可复用的方法、规则、风险结论落盘。

## goal
- 先提炼本轮会话里可复用的模式。
- 再判断应该沉淀到 `skill`、`docs`、`memory` 还是 `AGENTS.md`。
- 只有 `repo-wide` 且长期稳定的规则才允许上升到 `AGENTS.md`。
- 最后执行 `qmd update` 和 `qmd embed`，保证写回内容可检索。

## supporting-skills
- `gettokens-space-governance`：涉及 `space` 创建、命名、README、截图、debate 归档。
- `gettokens-doc-writeback`：涉及 `docs-linhay/dev/`、`docs-linhay/memory/` 写回与 `qmd` 同步。
- `gettokens-agents-governance-sync`：涉及 repo-wide 长期治理规则的增补或收敛。

## workflow
1. 识别本轮沉淀对象
   - 复用模式：排障路径、交付动作、边界判断、验收套路、目录约束。
   - 稳定偏好：语言、输出结构、验证门禁、路径习惯。
   - 关键结论：风险、决策、行动项、里程碑。
2. 先做落位判断
   - 仅当前任务或局部模块复用：优先更新项目级 `skills`。
   - 需要长期查阅的设计/治理说明：写入 `docs-linhay/dev/`。
   - 决策、行动项、里程碑、风险：写入 `docs-linhay/memory/YYYY-MM-DD.md`。
   - 只有当规则满足“跨模块、跨任务、长期稳定、repo-wide”四项时，才更新 `AGENTS.md`。
3. 明确本轮不是普通总结
   - 不能只输出自然语言 recap。
   - 必须至少产出一种可复用载体：`skill`、`docs`、`memory`、`AGENTS.md` 之一。
4. 执行写回
   - 新增或更新对应文件。
   - 若涉及 `AGENTS.md`，同步确保引用的项目级 skills 实际存在。
   - 若涉及 `space` 材料，按 `docs-linhay/spaces/<space-key>/...` 归档。
5. 验证闭环
   - 运行 `bash docs-linhay/scripts/check-docs.sh`。
   - 运行 `git diff --check`。
   - 执行 `qmd update && qmd embed`。

## do
- 把“整理”理解为正式沉淀动作，而不是“帮我总结一下”。
- 明确说明本轮新增或更新了哪些治理载体。
- 当规则尚未达到 repo-wide 稳定性时，停留在 `skill` 或 `docs`，不要过度上升到 `AGENTS.md`。

## dont
- 不要只写一段会话总结就结束。
- 不要把临时性、单模块、一次性经验直接写进 `AGENTS.md`。
- 不要跳过 `qmd update` 与 `qmd embed`。

## validation
- 收尾时必须说明：本轮沉淀落到了哪些载体、为什么这样落位。
- 若改了治理规则，`bash docs-linhay/scripts/check-docs.sh` 与 `git diff --check` 必须通过。
- `qmd update` 与 `qmd embed` 必须执行；若失败，要明确说明失败点与风险。
