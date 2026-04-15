# Codex Sessions 原始字段保留与展示 Debate（2026-04-15）

关联文档：
- `docs-linhay/features/codex-sessions-tab-2026-04-10.md`
- `docs-linhay/plans/2026-04-14-codex-sessions-project-first-exec.md`
- `docs-linhay/debate/20260414/codex-sessions/20260414-codex-sessions-tab-ui-ux-v01.md`

## 辩论背景
- `codex-sessions` 第二轮 `project-first` 改造已经完成，主表格当前固定为：
  - `名称 / id / 时间 / provider / 用量 / 菜单`
- 当前用户继续追问：
  - 单条会话能否区分是否是 `subagent`
  - 除了 `subagent` 还能推导出哪些类型
  - `forkedFromID / originator / source` 分别代表什么
- 初步代码核查显示：
  - rollout 原始 parser 已能解析 `forked_from_id / originator / source`
  - 事件类型集合已识别 `collab_agent_spawn_* / collab_agent_interaction_*`
  - 但 scanner / store / view model / UI row model 还没有把这些字段保留下来

## 当前事实
- 原始字段存在于 parser：
  - `libs/Providers/Sources/Providers/Codex/CodexGeneratedFiles.swift`
- sessions 扫描层当前仅保留：
  - `threadID / modelProvider / cwd / timestamp`
  - `libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift`
- sessions 列表记录当前仅保留：
  - `id / threadID / title / summary / modelProvider / archived / rolloutPath / cwd / updatedAt / stateRowCount / editable`
  - `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift`
- 当前 row UI model 没有任何原始字段展示位：
  - `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift`

## Round 1（2026-04-15 00:00，主题建立）

### 待辩论问题
1. 应不应该在 `codex-sessions` 保留原始字段，而不是只保留当前迁移视角字段。
2. 如果保留，最小保留集合应该是什么：
   - `forkedFromID`
   - `originator`
   - `source`
   - `subagent involvement`
3. 这些字段应该落在哪一层：
   - parser
   - scanner/session meta
   - session record
   - row ui model
4. 这些字段应该如何展示：
   - 主列
   - badge
   - 次级 subtitle
   - 菜单 / disclosure / tooltip / debug panel

### 参与者
- `Vector Tide（Codex）`
- `Chandrasekhar（内部 subagent）`
- `Aristotle（内部 subagent）`
- `Claude Code（外部 CLI）`
- `Gemini CLI（外部 CLI）`

### 我的初始立场
- 应该保留原始字段，但不应该把它们直接塞进主表格主列。
- 当前主表格已经被 `project-first` 冻结为高频浏览入口；原始字段更适合承载“血缘 / 来源 / 调试”语义，而不是替代当前主列。
- 因此更合理的方向应是：
  - 数据层先无损保留
  - UI 层再做分级展示

## 后续讨论记录

## Round 2（2026-04-15 03:xx，内部 subagents）

### Chandrasekhar

#### 观点
- 支持把 `forkedFromID / originator / source` 作为会话原始元数据完整保留，但反对直接塞进当前 6 列主表。
- 支持展示 `forkedFromID`，因为它最接近“会话血缘”，产品价值最高，也最容易被解释。
- 支持保留并可查看 `originator / source`，但只作为次级 metadata，不升级为主列。
- 支持展示 `subagent` 相关线索，但反对直接把线索强判定成 `isSubagent = true/false`。
- 明确反对把 `cliVersion`、完整 `git.repositoryURL`、原始 `collab_*` 事件列表直接丢进列表主视图。

#### 证据
- parser 层已经有完整 `session_meta` 原始字段：
  - `id / forkedFromID / timestamp / cwd / originator / cliVersion / source / modelProvider / git`
  - 见 `libs/Providers/Sources/Providers/Codex/CodexGeneratedFiles.swift:551`
  - 见 `libs/Providers/Sources/Providers/Codex/CodexGeneratedFiles.swift:983`
- parser 层也已经识别协作相关事件族：
  - `collab_agent_spawn_* / collab_agent_interaction_* / collab_waiting_* / collab_close_*`
  - 见 `libs/Providers/Sources/Providers/Codex/CodexGeneratedFiles.swift:1347`
- scanner 层当前开始丢字段，只保留：
  - `threadID / modelProvider / cwd / timestamp`
  - 见 `libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift:55`
  - 见 `libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift:169`
- store 层继续丢字段，`CodexSessionRecord` 当前没有任何 raw metadata 承载位：
  - 见 `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift:6`
  - 见 `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift:641`
- usage 异步扫描快路径不会顺手得到 `collab_*` 线索：
  - 见 `libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift:100`

#### 风险
- `source` 和 `originator` 目前只是原始字符串，没有稳定枚举；不适合过早升格为强语义标签。
- `collab_*` 是事件级线索，不是会话级真值；最多能说明“出现过协作痕迹”，不能严格等于“这条就是 subagent 会话”。
- 如果为了 `collab_*` 去全量扫完整 rollout，首屏性能会退化。
- 如果新增主列，会直接破坏这一轮 `project-first` 的表格扫描效率。

#### 建议行动
- 最小保留集合先落 `forkedFromID / originator / source`，全链路保留，但不改主表结构。
- `subagent` 线索单独做第二类轻量信号，建议是：
  - `hasCollabSignals`
  - 或 `collabEventTypes`
- 展示优先级建议：
  - `forkedFromID` -> row 下方 badge 或 metadata badge
  - `source` -> 短 badge
  - `originator` -> row menu / metadata disclosure
  - `collab` -> 弱语义 badge，如 `Subagent Clues`

### Aristotle

#### 观点
- 支持“数据层完整保留，默认 UI 只展示派生结论”，反对把 raw 字段直接塞进主表格。
- 支持“row 级衍生 badge + row menu/debug disclosure 展示原始字段”的两层方案。
- 明确区分两类信号：
  - `forked lineage`
  - `collab/subagent signals`
- 明确反对把 `forkedFromID / originator / source` 混入主列或 `summary` 第二行。

#### 证据
- 当前 sessions tab 的信息架构是：
  - overview card
  - section cards
  - table rows
  - 没有单独 session detail pane
  - 见 `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift:19`
- 主表格已固定为 6 列，且列宽硬编码，说明这是高密度扫描视图：
  - 见 `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:334`
  - 见 `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:583`
- row menu 已经承接 `rolloutPath / DB rows / Show in Finder / Copy Path` 这类次级信息，天然适合扩展 metadata：
  - 见 `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:417`
- UI model 层虽然当前没接 raw metadata，但仓库里已有未使用的 `CodexSessionsMetadataItemData`，更适合作为 metadata 承载：
  - 见 `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift:53`
  - 见 `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift:133`
- 现有 UI 语言里已有 `DisclosureGroup` 作为高级/调试信息折叠层先例：
  - 见 `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexAuxSharedViews.swift:388`

#### 风险
- 如果直接把 `forkedFromID` 解释成 `subagent`，会把血缘字段误判成角色类型。
- 如果把 `originator / source` 默认强展示，用户容易误以为它们是核心业务属性。
- 如果所有 raw 字段都只藏进 menu，发现性会偏低，用户还是无法快速识别“这条是不是 subagent 相关”。
- 如果把 raw 值塞进 `summary` 或 badge，长字符串会破坏表格节奏，尤其是完整 ID。

#### 建议行动
- 第一层只展示派生状态，不展示 raw string：
  - `Forked`
  - `Subagent` 或 `Collab`
- 第二层提供原始字段可查：
  - row menu 的 `Metadata` 或 `Debug Info`
- 第三层才考虑 disclosure：
  - 只有 metadata 项变多时，再引入二级展开，不要让 row 直接长成小型 inspector
- 字段分层建议：
  - 默认展示：派生 badge
  - 次级展示：`forkedFromID / originator / source`
  - debug-only：`collab_agent_spawn_* / collab_agent_interaction_*` 事件细节与计数

## Round 3（2026-04-15 03:xx，外部 CLI 参与状态）

### Claude Code
- 已尝试使用本机 `claude` CLI 参与只读 debate。
- 实际返回：
  - `Failed to authenticate. API Error: 401 {"error":"Invalid API key"}`
- 结论：
  - 本轮未形成可验证观点，不纳入共识，也不伪造其立场。

### Gemini CLI
- 已尝试使用本机 `gemini` CLI 参与只读 debate。
- 实际交互进入浏览器认证流程：
  - `Opening authentication page in your browser. Do you want to continue? [Y/n]:`
- 当前在无人工完成浏览器登录的前提下，未拿到可验证的正式输出。
- 结论：
  - 本轮未形成可验证观点，不纳入共识，也不伪造其立场。

## 共识

### 1. 原始字段应保留，但不应直接进入主表格主列
- 当前 `project-first` sessions tab 的主价值是“快速扫描”，不是“单条取证面板”。
- 因此：
  - 数据层应该无损保留原始字段
  - UI 层只做低干扰展示

### 2. 最小无损保留集合已经收敛
- 第一优先级：
  - `forkedFromID`
  - `originator`
  - `source`
- 第二优先级：
  - `hasCollabSignals`
  - 或 `collabEventTypes`
- 不建议在列表主链路保留完整 `collab_*` 原始事件 payload。

### 3. `subagent` 不能做强判定
- `forkedFromID != nil` 只能说明存在父会话或血缘关系。
- `collab_*` 只能说明出现过协作代理痕迹。
- `source / originator` 也只是来源线索。
- 因此当前更合理的表达是：
  - `Forked`
  - `Collab`
  - `Subagent Clues`
- 不应该在没有更强规则前直接产出 `isSubagent = true/false`。

### 4. 展示分层方向已基本一致
- 默认层：
  - 只展示高信号派生 badge
- 次级层：
  - 在 row menu / metadata disclosure 展示 raw fields
- debug 层：
  - 承接事件级 `collab_*` 细节

## 仍有分歧
- 当前没有实质性产品分歧，更多是实现粒度差异：
  - `source` 是做短 badge 还是只放 metadata
  - `Subagent` 文案是否过强，是否应降级成 `Collab` 或 `Subagent Clues`
- 这两个点属于文案和展示强度调优，不影响主结论。

## 裁决建议
- 这一轮 debate 可以先按以下结论冻结：
  - `forkedFromID / originator / source` 全链路保留
  - 主表格不新增 `Forked From / Originator / Source` 主列
  - 不把 raw 字段混入 `summary`
  - `subagent` 只展示为弱语义线索，不做强判定
  - 优先采用“派生 badge + metadata/menu/disclosure”的分级展示方案

## 后续行动建议
- 如果进入执行阶段，建议把实现拆成两段：
  1. 先做数据链路保留：
     - parser -> scanner -> store -> view model -> UI model
  2. 再做 UI 分级展示：
     - 先上 `Forked / Collab` 派生 badge
     - 再补 `Metadata / Debug Info`

## 本轮结论
- 内部讨论已达成共识。
- 外部 `Claude Code / Gemini CLI` 已尝试参与，但本机认证阻塞，未拿到可验证输出。
- 因此本轮可执行结论以内部 debate 收敛版本为准，不等待外部 CLI 进一步意见。

## Round 4（2026-04-15 04:xx，前提调整：字段必须在表格上可见）

### 新前提
- 产品方进一步明确：
  - 这些字段不能只藏在 `menu / disclosure`
  - 它们必须直接出现在 sessions 表格区域里

### 新裁决
- 在这个前提下，最合理的方案不是“新增三列”，而是“保留 6 列主结构，在单条 row 的表格单元内增加一行原始字段展示”。
- 也就是：
  - 仍然保持表头为 `名称 / id / 时间 / provider / 用量 / 菜单`
  - 但在 `Name` 列内，把当前仅有的 `title + summary` 扩成：
    - 第一行：`title`
    - 第二行：摘要或原始字段 chips
    - 第三行：必要时的补充字段 chips
- 这样字段确实“显示在表格上”，同时不把表头膨胀成 debug grid。

### 我当前的主张
- 表格内应该直接显示这 3 个字段，但显示形式应是“行内 metadata chips / subtitle”，不是新主列：
  - `forkedFromID` -> `forked:<short-id>`
  - `originator` -> `originator:<value>`
  - `source` -> `source:<value>`
- 如果同时存在 `collab` 线索，可以作为第四个弱语义 chip：
  - `collab`
  - 或 `subagent clues`
- 原始值要“短展示 + 可完整查看”：
  - 表格里显示截断值
  - menu / disclosure 保留完整值

### 具体展示建议

#### 方案 A：全部落在 `Name` 列下方
- 优先推荐。
- 原因：
  - `Name` 列本来就承载标题和 summary，最适合扩成“标题 + metadata”复合单元。
  - 不会挤压 `ID / Time / Provider / Usage / Menu` 现有列宽。
- 展示层级：
  - 第一行：会话标题
  - 第二行：`forked / source / originator` chips
  - 第三行：可选 `collab` 弱语义 chip 或摘要

#### 方案 B：`Name` 列显示一部分，`ID` 列补一部分
- 不推荐作为首选，但可作为备选。
- 可行形式：
  - `Name` 列显示 `forked / originator`
  - `ID` 列在 thread id 下方显示 `source`
- 问题：
  - 字段语义被拆散
  - 扫读路径不连续

#### 方案 C：新增主列
- 不推荐。
- 可读性成本过高，且和当前 `project-first` 表格方向冲突。

### 在“必须表格可见”的前提下，新的共识收敛
- 可以接受字段直接出现在表格里。
- 但这个“显示在表格里”更适合解释为：
  - row cell 内可见
  - 而不是表头新增 3 个主列
- 因此新的收敛版是：
  - `forkedFromID / originator / source` 在表格 row 内直接可见
  - 采用短值 chip 或副标题文本
  - 完整值仍保留在 menu / disclosure

### 明确反对
- 反对新增：
  - `Forked From`
  - `Originator`
  - `Source`
  作为 3 个新主列
- 反对把完整长值直接平铺在单行文本里
- 反对把 `collab_*` 原始事件数组直接显示在表格内

### 外部 CLI 参与状态补充
- 本轮已再次尝试让 `Claude Code` 和 `Gemini CLI` 参与“新前提”讨论。
- 当前结果仍然是：
  - `Claude Code` 未返回可验证 stdout
  - `Gemini CLI` 仍处于认证链路，未返回可验证 stdout
- 因此这轮关于“表格上必须显示字段”的裁决，仍以项目内代码事实和内部 agent 收敛意见为准。

## Round 5（2026-04-15 04:xx，进一步研究：表格内到底放哪）

### 新增代码事实
- 当前 row 的 `Name` 列结构非常简单：
  - 第一行 `title`
  - 第二行可选 `summary`
  - 见 `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:355`
- 但 `summary` 在当前 sessions 数据链路里实际上没有稳定来源，store 构建时直接写成了 `nil`：
  - 见 `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift:660`
- view model 和 section builder 只是机械传递这个空值：
  - 见 `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:678`
  - 见 `nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift:174`
- 结论：
  - `Name` 列的第二行当前几乎是空槽位。
  - 所以把 raw fields 放进 `Name` 列下方，不是在“抢摘要位置”，而是在复用一个尚未真正承载业务信息的显示位。

### 进一步收敛后的判断
- 如果你的要求是“这些字段必须出现在表格上”，那最合理的落点已经更明确了：
  - 不该去扩表头
  - 应该优先占用 `Name` 列现有的副文本区域
- 这比我上一轮给出的结论更强一点：
  - 现在不仅是“可以放在 Name 列”
  - 而是“Name 列下方几乎就是唯一低成本、低破坏、高一致性的主落点”

### 三种落法的优先级重排

#### 1. 首选：`Name` 列下方 chips / metadata 行
- 形式：
  - `forked:<short-id>`
  - `originator:<value>`
  - `source:<value>`
  - 可选 `collab`
- 原因：
  - 真正满足“表格中可见”
  - 不增加新主列
  - 不挤压时间、provider、usage 这些已有高频列
  - 与当前 `title + summary` 复合单元结构天然兼容

#### 2. 次选：`Name` 列下方单行 metadata 文本
- 形式：
  - `forked abcd123 · source cli · originator codex`
- 优点：
  - 实现面可能更轻
- 缺点：
  - 可扫读性比 chips 差
  - 长值会更容易糊成一行

#### 3. 末选：新增主列
- 只有在产品明确坚持“每个字段必须和 Time / Provider 一样独立成列”时才考虑。
- 当前代码和视觉结构都不支持把它作为默认答案。

### 哪些字段值得直接出现在表格里
- 值得直接出现：
  - `forkedFromID`
  - `originator`
  - `source`
- 但都应该是“短展示”：
  - `forkedFromID` 显示短 ID，不显示完整长串
  - `originator / source` 显示原始值，但应限制长度
- 可以作为衍生补充：
  - `collab`
  - `subagent clues`
- 不值得直接出现在表格里：
  - `cliVersion`
  - `git.repositoryURL`
  - 完整 `collab_*` 事件名数组
  - 完整 `forkedFromID`

### 最新裁决建议
- 如果后续进入执行，不要再围绕“是否新增主列”来摇摆。
- 更应该直接冻结为：
  - 原始字段在表格中显示
  - 显示位置固定在 `Name` 列下方
  - 展示形式优先采用短值 chips
  - 完整值继续保留在 menu / disclosure

## Round 6（2026-04-15 04:xx，定点方案评估）

### 议题
- 新提案：
  - `Forked From` 放在 `ID` 列下方
  - `originator / source` 合并成一个单独新列

### 判断
- 这是一个比“新增 3 个主列”更合理的中间方案。
- 我对它的结论是：
  - `Forked From` 放在 `ID` 列下方，我支持。
  - `originator / source` 合并成一个新列，我谨慎支持，但不把它当首选。

### 为什么支持 `Forked From` 挂在 `ID` 列
- `forkedFromID` 本质上就是“另一个 session/thread 的标识符”，语义上和 `ID` 是同一类信息。
- 放在 `ID` 列下方，比放在 `Name` 列下方更整洁，也更符合用户扫读路径：
  - 第一眼看当前 ID
  - 第二眼看它 fork 自谁
- 只要采用短 ID 展示，这个位置是成立的。

### 为什么对 `originator / source` 开新列保持谨慎
- 这个思路的优点很明确：
  - 发现性比藏在 `Name` 列下方更强
  - 语义上也比把它们混进 `summary` 清晰
  - `source / originator` 确实是一类“来源信息”，合并成一列比拆成两列合理得多
- 但问题也很明确：
  - 当前表头已经是 6 列，且 `ID / Time / Provider / Usage / Menu` 都是固定宽度，见 `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:583`
  - 一旦再加一列，实际被压缩的只能是 `Name` 列
  - 而 `project-first` 模式下，`Name` 列才是主要扫读入口

### 因此，这个方案的真实取舍是
- 你拿到了更强的来源字段可见性
- 但会牺牲：
  - 标题可读空间
  - 小窗口下的表格稳定性
  - 项目分组场景下的横向密度

### 最终排序

#### 首选
- `Forked From` 放 `ID` 列下方
- `originator / source` 仍放 `Name` 列下方的 metadata 行

#### 次选
- `Forked From` 放 `ID` 列下方
- `originator / source` 合并成一个新列

#### 不推荐
- `Forked From / Originator / Source` 各开一列

### 如果坚持给 `originator / source` 开一列，建议的约束
- 必须是一个合并列，不要拆成两列。
- 这列应该叫：
  - `Source`
  - 而不是 `Originator/Source`
- 列内两行展示：
  - 第一行：`source`
  - 第二行：`originator`
- 长值必须截断。
- 这列宽度必须可控，不能继续无限侵蚀 `Name` 列。

### 这一轮的最新裁决
- `Forked From` 放在 `ID` 列下方，是成立的，且比放在 `Name` 列更合适。
- `originator / source` 开一个合并列，不是错误方向，但属于“为了更强可见性，接受横向密度下降”的方案。
- 如果目标是更稳、更适合当前 sessions IA，我仍然优先：
  - `Forked From -> ID 列下方`
  - `originator / source -> Name 列下方 metadata`

## Final Ruling（2026-04-15 04:xx）

### 最终裁决
- 采用：
  - `Forked From` 放在 `ID` 列下方
  - `originator / source` 不单独开列，放在 `Name` 列下方的 metadata 区
- 不采用：
  - `originator / source` 合并成一个新列

### 裁决理由
- `Forked From` 与 `ID` 属于同一类信息，都是标识关系。放在 `ID` 列下方语义最顺，也最便于用户理解“当前会话是谁 fork 出来的”。
- `originator / source` 虽然也是重要字段，但它们更像来源上下文，不是主索引字段。把它们做成 `Name` 列下方的 metadata，更符合信息层级。
- 当前表格已经固定为高密度扫描结构，`ID / Time / Provider / Usage / Menu` 基本都有稳定宽度；如果再开一列，主要被压缩的是 `Name` 列，而 `Name` 列恰好是 `project-first` 模式下最重要的扫读入口。
- 当前 `summary` 在 sessions 链路里基本是空槽位，因此把 `originator / source` 放进 `Name` 列下方，不是在抢已有内容，而是在复用现成位置。

### 冻结后的 UI 结构
- `Name` 列：
  - 第一行：`title`
  - 第二行：`originator / source` metadata
- `ID` 列：
  - 第一行：当前 session id
  - 第二行：`forked from <short-id>`
- 其他列维持不变：
  - `Time`
  - `Provider`
  - `Usage`
  - `Menu`

### 字段显示规则
- `forkedFromID`
  - 只显示短 ID
  - 完整值保留在 menu / disclosure
- `originator`
  - 显示原始值，但需要截断
- `source`
  - 显示原始值，但需要截断
- `collab` 相关
  - 暂不进入独立主列
  - 如需出现，只作为弱语义标记，不替代上述 3 个字段

### 放弃备选方案的原因
- 放弃“`originator / source` 合并新列”，不是因为它不可行，而是因为它会为了来源信息的可见性，过度侵蚀主标题阅读空间。
- 在当前 IA 下，标题可读性比来源字段的横向独立性更重要。

### 执行口径
- 后续若进入实现，按这一版作为唯一执行方案，不再并行维护第二套布局判断。
