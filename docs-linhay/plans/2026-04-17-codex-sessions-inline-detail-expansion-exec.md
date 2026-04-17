# 2026-04-17 Codex Sessions 行内详情展开执行计划

## 目标

把 `Codex Sessions` 的会话详情从列表底部统一面板改为“点击后在对应会话行下方展开”，同时把详情区重设计为更紧凑的行内检查面板。

## 实施范围

1. `UnifiedCodexSessionViews.swift`
2. `CodexSessionsTabView.swift`
3. `CodexSessionsCardSnapshotTests.swift`
4. 对应 snapshot 基线

## TDD 顺序

### Phase 1：先补快照场景

1. 新增“selected row inline detail”快照测试
2. 更新现有 detail panel 快照测试，使其反映新的紧凑详情布局
3. 先运行快照测试，确认新快照在当前实现下失败或产生录制差异

### Phase 2：改 shared section 容器

1. 将 `CodexSessionsSectionCardView` 改成泛型容器
2. 增加 `expandedRowID` 与 `expandedRowContent`
3. 在 row 渲染循环里，把匹配 row 的 expanded content 插入该 row 后方
4. 保留默认 initializer，避免其它调用点回归

### Phase 3：改 tab 视图与详情面板

1. 删除页面底部统一 `CodexSessionsDetailPanelView`
2. 在 section card 调用处传入内联展开 content
3. 将 `CodexSessionsDetailPanelView` 改造成紧凑 inset 面板
4. 保持 resume / Finder / copy 行为闭包不变

### Phase 4：验证与收尾

1. 运行 `CodexSessionsCardSnapshotTests`
2. 如选择逻辑受影响，补跑 `CodexSessionsTabViewModelTests`
3. 更新 `docs-linhay/memory/2026-04-17.md`

## 验收检查表

1. 点击任意会话，详情出现在该行正下方
2. 切换选中行时，详情随行移动
3. 列表底部不再有统一详情块
4. 详情高度明显低于旧版
5. Resume / Finder / Copy 动作仍可用
6. 快照测试通过

## 风险

1. snapshot 需要重录，基线会有视觉噪声
2. 若 section card 当前已有未提交改动，必须小 patch 合并，避免覆盖
3. 若 `tableContainer` 后续重新启用，也要同步支持 expanded row；本轮优先覆盖当前实际走的 compact 路径
