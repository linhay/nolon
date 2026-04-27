# Skill: gettokens-agents-governance-sync

用于同步 repo-wide 且长期稳定的治理规则到 `AGENTS.md`，避免把局部经验误提升为全局约束。

## trigger
- 用户要求项目具备新的长期治理能力。
- 某条规则已经跨模块、跨任务重复出现，并且稳定成立。
- 需要让后续 agent 在进入仓库时默认遵守某项固定流程。

## decision-gate
只有同时满足以下条件，才允许更新 `AGENTS.md`：
1. `repo-wide`：不局限于单个模块或单次任务。
2. 长期稳定：预计后续多轮会持续生效。
3. 可执行：能转成明确步骤、边界、门禁或目录约束。
4. 可验证：收尾时能说明如何自检。

若任一条件不满足，改为更新项目级 `skills` 或 `docs-linhay/dev/`。

## workflow
1. 先做上升判断
   - 单模块经验：停留在 `skill` 或 `space/dev`。
   - 全局流程能力：再考虑 `AGENTS.md`。
2. 更新方式
   - 只做增补，不破坏既有路径规范。
   - 新规则旁边尽量补“适用边界”和“与 skill 的分工”。
3. 同步校验
   - 若 `AGENTS.md` 引用了项目级 `skills`，对应文件必须存在。
   - 治理说明同步写入 `docs-linhay/dev/`。

## do
- 把 `AGENTS.md` 作为全局入口，而不是细节堆放区。
- 明确“什么应进 AGENTS，什么不应进 AGENTS”。

## dont
- 不要把一次性修复、临时路径、个人偏好直接写进 `AGENTS.md`。
- 不要新增规则但不补对应执行载体。

## validation
- `AGENTS.md` 中新增规则必须满足 `decision-gate`。
- 若引用了 `gettokens-*` skills，这些 skill 文件必须存在并可被发现。
