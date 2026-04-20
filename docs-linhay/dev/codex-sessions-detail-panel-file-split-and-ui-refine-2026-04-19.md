# 2026-04-19 Codex Sessions 详情面板拆分与 UI 收口设计

## 背景

当前会话详情虽然已经改为“行内展开”，但实现仍然全部堆叠在 `CodexSessionsTabView.swift` 中：

1. 主列表与详情视图耦合在同一文件
2. 详情数据模型与详情视图没有文件级边界
3. 后续继续扣 UI 细节时，主文件可读性会继续恶化

同时，详情卡片的 UI 还有明显收口空间：

1. 信息块层级不够稳定
2. 首屏重心不够聚焦
3. 复制动作分散，视觉噪声偏高

## 目标

本轮只解决两个问题：

1. 把会话详情面板拆成独立组件和独立文件
2. 在不改变数据口径和交互主流程的前提下，重排详情 UI 的信息层级

## 非目标

1. 不改详情数据来源
2. 不改 timeline / usage 的按需加载策略
3. 不改行内展开机制
4. 不引入新的设计主题或全局视觉语言

## 2026-04-20 二次收口补充

本轮继续只做 UI 信息架构收口，不改数据口径：

1. 当一个分组内只有 1 条会话时，不再强调“组”的视觉边界，尽量降级为接近单条会话的展示语义
2. 详情头部的文件入口不再显示 rollout 文件名，只保留动作语义，文案改为“在 Finder 打开”一类的动作标题
3. 详情面板取消“卡中卡”观感，弱化独立卡片边框与内层分块，改为更像选中条目的延展详情

原因：

1. 大量单条 group 会让列表扫描成本更高，视觉上也会造成多余的 header 噪声
2. 文件名已经体现在会话 identity 中，头部动作区重复出现会增加干扰
3. 行内展开的核心目标是“和条目连成一体”，不是在条目下再叠一个新的独立卡片

## 2026-04-20 缓存语义补充

当前发现一个和 UI 体验直接相关的加载缺陷：

1. 文件级 projection cache 和 SQLite usage index 都已经落地
2. 但 `projection cache` 只在 `reload(mode: .initial) && allRows.isEmpty` 时读取
3. 再次进入页面、前后台切换后的 stale refresh、以及显式 refresh，并不会先展示持久化快照

这会导致：

1. 用户体感上的“首次进入页面”未必走缓存
2. 单例 `CodexSessionsTabViewModel` 已存在时，页面出现直接走 refresh 链路，绕过 projection cache
3. 已有持久化快照的情况下，仍然要等真实扫描返回，违背“先展示缓存、后台慢慢对账”的目标

本轮调整目标：

1. 把文件级 projection cache 升级为 `Codex Sessions` 页面的统一首屏展示源
2. `handleViewAppearance()` 在已存在单例 ViewModel 时，仍可先应用持久化快照
3. `refresh()` / stale refresh 路径也先读 projection cache，再后台 reconcile
4. SQLite usage index 继续只负责 usage/search/sort 预热，不承担列表主快照职责

## 文件拆分策略

### 保留在 `CodexSessionsTabView.swift` 的内容

1. 详情展开入口
2. `detailPanelData(for:in:)` 数据组装
3. 详情相关的 action 回调接线

### 新增独立文件

1. `CodexSessionsDetailPanelData.swift`
   - `CodexSessionsDetailPanelData`
   - `CodexSessionsDetailUsageData`
   - `CodexSessionsDetailTimelineData`
2. `CodexSessionsDetailPanelView.swift`
   - `CodexSessionsDetailPanelView`
   - 仅保留详情视图内部的私有子结构与样式工具

这样做的原因：

1. 列表编排和详情渲染职责分离
2. 后续迭代详情 UI 不再污染主列表文件
3. 快照测试可直接面向独立组件维护

## UI 信息架构

### 第一层：概览头部

1. 标题
2. 状态标签
3. provider / group / updated 摘要
4. 主动作 `Resume`
5. 次动作 `Copy Command`、`Show in Finder`

### 第二层：核心内容区

使用固定三块主信息：

1. `Usage`
   - total
   - input / output / cached
2. `Identity`
   - session id
   - thread id
3. `Timeline`
   - started
   - last activity
   - updated

目标是让用户在首屏完成“量级判断 + 标识确认 + 时间判断”。

### 第三层：上下文

1. project path
2. group path
3. rollout path

统一作为路径清单，保留复制能力，不再与主信息竞争首屏权重。

### 第四层：诊断信息

1. DB rows
2. metadata items

保留折叠式呈现，默认不展开。

## 视觉收口原则

1. 主面板数量固定，避免继续增加平级小卡
2. 复制操作尽量内嵌在字段行尾，减少额外按钮组
3. `Usage` 作为最强信息块，需要明显比普通字段更有视觉权重
4. 路径和诊断只负责补充，不抢首屏注意力
5. 控制卡片高度，保持在大列表里可连续浏览

## 测试策略

延续现有 `CodexSessionsCardSnapshotTests`：

1. 保留现有详情面板快照场景
2. 用快照验证新版层级和紧凑度
3. 不新增与视觉无关的 ViewModel 测试

## 验收标准

1. 详情面板相关视图与数据模型已拆为独立文件
2. `CodexSessionsTabView.swift` 不再承载详情视图具体实现
3. 首屏能清晰看到 usage / identity / timeline
4. 复制与动作入口更集中，布局更稳
5. 快照测试通过，或明确记录基线变化

## 2026-04-20 第二轮 UI 收口

### 问题复盘

1. 当前详情面板虽然已拆文件，但内部仍保留 `Context / Identity / Diagnostics` 的段落化结构，视觉上还是一个独立小面板。
2. `onCopySessionID`、`onCopyStartedAt`、`onCopyLastActivity` 已有能力接线，但当前 UI 没有把这些复制能力收敛到稳定入口。
3. 下半区信息仍然像三段小卡片堆叠，和用户要求的“与条目融合为一体”不一致。

### 第二轮收口方向

1. 头部维持标题、状态、摘要标签和主动作。
2. 增加统一 `More` 菜单，收纳：
   - Copy Session ID
   - Copy Started At
   - Copy Last Activity
   - Copy Rollout Path
3. 下半区压成单一 metadata rail，只保留：
   - Project
   - Thread ID
   - Diagnostics
4. `Diagnostics` 保留折叠，但不再额外包成 panel card，而是作为 rail 的最后一段延展。

### 目标体验

1. 用户点击某一行后，会感知到这是该行的“展开体”，不是另一张卡片。
2. 关键信息仍在首屏，但复制型操作不再把面板纵向拉长。
3. 缺失 timeline / usage / thread 时，布局仍然稳定，不会出现空白大洞。

## 2026-04-20 第三轮头部去重

1. 问题确认：详情是行内展开，选中行本身已经展示会话标题，因此详情头部再次显示同一标题会造成重复。
2. 调整：详情头部移除重复 title 和左侧会话图标，只保留摘要标签、summary 文本和动作区。
3. 目标：让详情视觉上更像该行的延展信息，而不是第二个 session card 头部。

## 2026-04-20 第四轮交互收口

1. 问题确认：`More` 菜单虽然能承接复制动作，但会重新引入“详情卡自己再长一套工具栏”的负担，和当前的一体化目标冲突。
2. 调整：详情头部只保留 3 个动作：
   - `Resume`
   - `Copy Command`
   - `Show in Finder`
3. 调整：`Diagnostics` 不再保留折叠或二级交互，直接压成单行摘要，和 `Project / Thread ID` 一样作为 metadata rail 的一部分。
4. 工程要求：删除已经失效的复制型接线与数据字段，避免详情组件接口继续偏离真实 UI。
