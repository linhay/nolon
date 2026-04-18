# 2026-04-18 Codex Sessions 详情卡重设计执行计划

## 目标

重做会话行内详情卡，让用户在大规模会话列表中能快速看清：

1. 当前会话的主用量
2. 可复制的会话标识
3. `Started / Last activity`
4. 可直接执行的高频动作

同时控制详情卡高度，避免再次变成长条诊断面板。

## 设计方向

- 继续沿用现有 app shell 视觉语言，不引入新主题
- 信息密度高，但层级明确；把“用量”提升为首屏主信息
- 诊断信息保留，但降级到底部
- 时间口径严格使用 `Started / Last activity`，不伪装成“结束时间”

## 信息架构

### 首屏保留

1. 标题
2. 状态
3. 主用量：`total / in / out / cached`
4. 会话标识：优先展示可复制的 `Session ID`
5. 时间：`Started`、`Last activity`
6. 上下文：provider / group
7. 高频动作：`Resume`、`Copy Session ID`、`Copy Command`、`Show in Finder`

### 次级区域

1. Summary
2. Project path / rollout path
3. DB rows
4. 诊断元数据：`forked from / source / originator`

### 明确不做

1. 不显示伪精确 `Ended`
2. 不把全部 metadata 放到首屏
3. 不增加新的大 banner 或高卡片
4. 不在列表阶段预加载 timeline

## 数据口径

1. `Session ID`
   直接展示 rollout/session 路径级标识，不再复用 `displayID`
2. `Started`
   rollout 首个可解析时间戳
3. `Last activity`
   rollout 最后一个可解析时间戳；若时间线还未加载或加载失败，明确展示 `Loading… / Unknown`
4. `Usage`
   直接使用结构化 `CodexSessionTokenTotals`

## TDD 顺序

### Phase 1：先补文档和测试数据模型

1. 更新 debate 结论，补“还需要什么”的共识
2. 更新 `CodexSessionsDetailPanelData` 对应的快照工厂
3. 更新 `MockCodexSessionsService`，补 timeline mock 能力

### Phase 2：改详情卡视图

1. 完成 `CodexSessionsDetailPanelView` 的五段式布局
2. 接入 `Session ID`、`Started`、`Last activity`
3. 接入复制动作与用量 hero
4. 控制整体高度与窄宽度换行行为

### Phase 3：改 ViewModel / Store

1. 保持 timeline 按需加载，仅在选中详情时触发
2. 维持 selection、search、grouping、sorting 期间的 timeline 状态一致性
3. 为 store 补 rollout timeline 解析测试

### Phase 4：验证

1. 运行 `CodexSessionsCardSnapshotTests`
2. 运行 `CodexSessionsTabViewModelTests`
3. 运行 `CodexSessionStoreTests`
4. 如快照变化，更新基线

## 验收标准

1. 点击会话后，详情卡仍然在该会话下方展开
2. 详情首屏能直接看到主用量
3. 用户可一键复制会话标识
4. 用户可看到 `Started / Last activity`
5. 详情卡高度明显低于旧版长面板
6. 搜索、分组、排序、刷新后详情不会出现明显错位或错误数据
7. 测试通过，或明确记录阻塞与风险

## 风险

1. timeline 依赖 rollout 文件存在且可解析，异常路径只展示 `Loading… / Unknown`
2. timeline 失败后的显式重试目前通过再次点击同一会话触发，后续可视需要补独立 retry action
3. 快照测试会有视觉基线变更

## 2026-04-18 第三轮收口

### 调整原因

- 第二轮详情卡虽然已经把字段补齐，但布局仍然偏“把很多小卡堆在一起”：
  - 标题、状态、上下文、用量、动作都在抢首屏注意力
  - identity / path / diagnostics 都采用独立容器，导致 inline 展开时噪声过重
  - 复制动作被拆散在 action chips 和字段行之间，交互路径不稳定

### 新版信息架构

1. 抬头区
   - 标题
   - 状态
   - provider / group / updated 摘要标签
   - 高频动作：`Resume`、`Copy Command`、`Show in Finder`
2. 主面板
   - `Usage` 单独作为主信息面板
   - `Timeline` 汇总 `Started / Last activity / Updated`
   - `Identity` 汇总 `Session ID / Thread ID`
3. 次级面板
   - `Context` 承载 project / group path / rollout path
4. 低频信息
   - `Diagnostics` 单独折叠，默认不展开

### 结果口径

- 主阅读流从“多卡片堆叠”改为“工具条 + 主面板 + 次级面板 + 折叠诊断”。
- copy 动作回到对应字段右侧，不再依赖额外 action chips。
- 诊断元数据不再默认铺开，避免把列表浏览节奏打断。

### 验证

- `xcodebuild test -skipPackageUpdates -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests` 通过
