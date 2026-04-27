# AGENTS 执行规范（精简可执行版）

## 0. 路径规范（不可删）
以下目录结构为长期约束，后续修改 `AGENTS.md` 时不得删除，只能增补：

```text
.
├── AGENTS.md          # 行为规则，可按任务优化但需保留路径规范
└── docs-linhay/       # 项目文档系统目录：开发计划、需求文档、技术文档等
    ├── spaces/        # 以 feature / topic / milestone 为单位的工作空间根目录
    │   └── <space-key>/
    │       ├── README.md      # 当前 space 的需求背景、目标、范围、验收标准
    │       ├── plans/         # 开发计划、迭代规划、里程碑
    │       ├── screenshots/   # 截图，按日期/模块分层存放
    │       └── debate/        # 多 agent 辩论文档，按日期和主题分层存放
    ├── dev/          # 研发文档（架构、技术方案、测试策略、数据字典等）
    ├── memory/       # 记忆系统（MEMORY.md + 每日日志）
    ├── references/   # 参考项目、外部资料归档
    └── scripts/      # 自动化脚本及其说明文档
```

补充约束：
1. `spaces` 为正式目录名，后续所有文档落位和引用都以该路径为准。
2. `<space-key>` 采用可追踪的英文 slug，优先使用 `<YYYYMMDD>-<topic>` 或稳定功能名，禁止空格、中文、`latest`、`final`。
3. 每个 `space` 的入口文档固定为 `README.md`。

## 1. 全局原则
1. BDD + TDD 必须先行：先场景与验收标准，再失败测试，再实现。
2. 全程中文沟通。
3. 小步提交、可回归验证，避免大块不可控改动。
4. E2E 场景覆盖核心功能，单元测试覆盖边界条件。
5. 文档与记忆同步更新，保持信息一致性。
6. 任何改动都要考虑对后续维护者的可理解性和可操作性。
7. 涉及 Web / 前端体验优化时，默认由 Gemini 主导前端实现；Codex 负责业务逻辑、接口契约、状态流转、测试门禁、回归验收与最终集成。
8. 前端改动若影响后端接口、领域模型或关键交互闭环，必须先由 Codex 明确边界，再交给 Gemini 落地，避免只改视觉不改业务完成度。
9. 当一次会话中出现“有用且重复出现”的行为模式、排障路径或交付动作时，必须先识别复用边界，再优先新增或更新项目级 `skills`；只有当规则已经上升为 repo-wide、长期稳定的约束时，才同步更新 `AGENTS.md`。
10. 用户说“整理”时，默认触发一次正式会话沉淀流程，不视为普通总结：先提炼本轮可复用模式，再判断应落到 `skills`、`docs-linhay/dev/`、`docs-linhay/memory/` 还是 `AGENTS.md`；只有 repo-wide 且长期稳定的规则才允许写入 `AGENTS.md`；收尾必须执行 `qmd update` 与 `qmd embed`。

## 2. 标准工作流（必须）
1. 明确需求边界与验收条件。
2. 先补测试并确认失败（红灯）。
3. 最小实现让测试通过（绿灯）。
4. 必要重构并保持测试通过。
5. 更新相关文档与记忆。
6. 若本次任务提炼出可复用的项目动作、流程或知识边界，新增或更新对应 `skills`；若同时形成长期稳定规则，再更新 `AGENTS.md`。

## 3. 测试门禁（必须）
1. 任何功能改动都要有对应测试（新增或更新）。
2. 未运行测试时必须明确说明原因与风险。
3. 禁止“只改代码不验证”。
4. 纯文档或治理规则调整若无可执行测试，至少要完成结构自检、路径校对与引用校对，并在交付说明中明确写明“未运行自动化测试”的原因。

## 4. 文档系统规则（docs-linhay）
`docs-linhay/` 是项目文档系统目录，按类型分文件夹：
1. `docs-linhay/spaces/<space-key>/README.md`：单个需求空间的背景、目标、范围、验收标准、相关链接。
2. `docs-linhay/spaces/<space-key>/plans/`：该需求空间下的开发计划、迭代规划、里程碑。
3. `docs-linhay/spaces/<space-key>/screenshots/`：该需求空间下的截图归档。
4. `docs-linhay/spaces/<space-key>/debate/`：该需求空间下的多 agent 辩论文档。
5. `docs-linhay/dev/`：研发文档、技术方案、治理说明。
6. `docs-linhay/memory/`：记忆系统（`MEMORY.md` + 每日日志 `YYYY-MM-DD.md`）。
7. `docs-linhay/references/`：参考项目、外部资料归档。
8. `docs-linhay/scripts/`：自动化脚本及其说明文档。

文档落位硬约束：
1. 需求变更先写对应 `space`，再改代码。
2. 技术方案和治理说明放 `docs-linhay/dev/`。
3. 截图、计划、辩论材料必须跟着对应 `space` 走。
4. 外部参考资料统一归档到 `docs-linhay/references/`。

项目级 skills：
1. 用户说“整理”或要求做正式沉淀时，优先使用 `gettokens-session-organize`。
1. 涉及 `space` 创建、命名、README 模板、截图或 debate 归档时，优先使用 `gettokens-space-governance`。
2. 涉及文档写回、memory 写回、`qmd update` / `qmd embed` 同步时，优先使用 `gettokens-doc-writeback`。
3. 涉及 AGENTS 级长期治理规则时，优先使用 `gettokens-agents-governance-sync`。

## 5. 记忆系统规则（必须）

### 5.1 Retrieval（查询）
查询历史信息时，禁止先全量读取 `docs-linhay/memory/MEMORY.md` 或 `docs-linhay/memory/*.md`。按顺序执行：
1. `qmd query "<问题>"`
2. `qmd get <file>:<line> -l 20`
3. 仅当 `qmd` 无结果时，才回退直接读文件

### 5.2 Writeback（写回）
出现以下情况必须写入记忆：关键决策、行动项、偏好变化、里程碑、风险结论。
1. 写入 `docs-linhay/memory/YYYY-MM-DD.md`
2. 执行 `qmd update && qmd embed`
3. 每周合并到 `docs-linhay/memory/MEMORY.md`（只保留稳定高价值信息）

### 5.3 Collection 管理
`qmd` 需支持自动建立 collection，规则如下：
1. 首次在项目中执行 `qmd update` 时，若 collection 不存在，自动创建。
2. collection 名称与项目目录名保持一致。
3. 跨项目查询时，通过 `qmd query --collection <name> "<问题>"` 指定 collection。
4. CI/CD 环境中应跳过 collection 初始化（通过环境变量 `QMD_SKIP_INIT=1` 控制）。

## 6. 文档工具（推荐）
1. 新建 `space` 时优先使用 `docs-linhay/scripts/create-space.sh <space-key>`。
2. 提交前或调整治理规则后，运行 `docs-linhay/scripts/check-docs.sh` 做结构校验。

## 7. 完成定义（DoD）
1. 验收场景满足。
2. 相关测试通过，或已说明阻塞、未测原因与风险。
3. 文档已更新到正确目录。
4. 有意义变更已写入记忆并可检索。
5. 若本次工作产生了可复用且重复出现的行为模式，已完成对应 `skills` / `AGENTS.md` 的新增或更新，或已明确说明为何暂不沉淀。
