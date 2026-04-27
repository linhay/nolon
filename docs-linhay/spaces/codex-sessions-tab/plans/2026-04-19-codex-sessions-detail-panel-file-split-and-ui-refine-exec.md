# 2026-04-19 Codex Sessions 详情面板拆分与 UI 收口执行计划

## BDD 场景

### 场景 1

- Given 用户在会话列表中展开某个会话
- When 详情面板渲染
- Then 首屏应先看到 usage、identity、timeline 三类核心信息

### 场景 2

- Given 开发者需要继续维护会话详情卡
- When 阅读 `CodexSessionsTabView.swift`
- Then 不应再在该文件里同时处理详情视图实现与列表编排

### 场景 3

- Given timeline 缺失或 usage 未加载
- When 详情面板展示
- Then 仍应保持布局稳定，不膨胀成异常高卡片

## TDD 顺序

1. 先补设计文档与执行计划
2. 先拆分详情面板类型到独立文件
3. 更新详情面板视图布局
4. 运行 `CodexSessionsCardSnapshotTests`
5. 若快照变更，更新基线并确认变更符合设计目标

## 实施步骤

1. 新增详情数据模型文件
2. 新增详情视图文件
3. 从 `CodexSessionsTabView.swift` 删除重复定义并保留装配入口
4. 重排详情卡头部、核心区、上下文区、诊断区
5. 跑详情相关快照测试
6. 写回 memory 并执行 `qmd update && qmd embed`

## 2026-04-20 补充执行项

1. 增加单条分组降级场景测试，锁定“只有一个 session 的 group 不强调 group chrome”
2. 调整详情头部文件按钮文案，改为动作语义而不是文件名语义
3. 重排详情容器样式，移除“卡中卡”层级感
4. 运行 `CodexSessionsCardSnapshotTests` 和必要的 builder / view model 测试

## 2026-04-20 缓存链路补充执行项

1. 新增“再次进入页面仍先展示 projection cache”的回归测试
2. 新增“refresh 路径也先展示 projection cache”的回归测试
3. 把读取 cached snapshot/skeleton 的逻辑从“仅 initial cold load”抽成统一入口
4. 保持 dirty/freshness 判定只决定是否短路后台 reconcile，不决定是否先展示 cache

## 2026-04-20 详情 UI 第二轮执行项

1. 先用快照场景锁定“详情下半区只保留 Project / Thread ID / Diagnostics”的紧凑布局
2. 在详情头部动作区增加统一 `More` 菜单，承接 Session ID / Started At / Last Activity / Rollout Path 的复制能力
3. 去掉详情内部多段 panel card 观感，改成单一 metadata rail + divider 的一体化布局
4. 跑 `CodexSessionsCardSnapshotTests`，确认详情快照和 inline expand 快照通过

## 2026-04-20 详情头部去重执行项

1. 去掉详情头部重复 title
2. 去掉左侧会话 icon
3. 保留摘要标签、summary 和动作区
4. 复跑详情快照，确认头部高度进一步收缩

## 2026-04-20 第四轮交互收口执行项

1. 删除 `More` 及其内部复制动作，不再保留隐性工具集合
2. 把 `Diagnostics` 固化为单行 metadata row
3. 清理详情组件和挂载点中已经失效的回调与数据字段
4. 复跑 `CodexSessionsCardSnapshotTests`，确认行内展开的高度和密度仍然稳定

## 风险

1. 详情视图拆文件后，测试 target 的可见性若配置不完整，可能出现编译问题
2. 快照高度和内容密度变化后，需要同步接受新的视觉基线
3. 若现有 `NolonUI.CodexSessionsSectionCardView` 对展开容器高度有隐藏约束，可能需要二次微调 spacing

## 完成定义

1. 独立文件拆分完成
2. 详情面板 UI 按新层级展示
3. 快照测试通过
4. 文档与 memory 已同步
