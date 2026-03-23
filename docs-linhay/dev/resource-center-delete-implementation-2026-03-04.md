# 资源中心删除实现说明（2026-03-04）

## 关联需求
- `docs-linhay/features/resource-center-delete-and-text-selection-2026-03-04.md`

## 设计摘要
1. 新增删除编排器 `ResourceDeletionCoordinator`：
- 输入：资源类型、slug、删除目标、Provider 列表
- 处理：逐 Provider 卸载 + 可选全局缓存删除
- 输出：`ResourceDeleteExecutionResult`（attempt/success/failures）
2. 新增目标选择 Sheet `ResourceDeleteTargetSheet`：
- Provider 定向删除
- 全 Provider + 全局缓存删除（二次确认）
3. 在 `ResourceCatalogGridView` 接入三类资源删除回调，并统一展示执行结果。
4. `MainSplitViewModel` 注入删除协调器，落地删除动作到 `ResourceInstaller.uninstall` 与 `NolonManager` 本地缓存路径。

## 关键文件
1. `nolon/Skills/Views/Remote/ResourceDeletionModels.swift`
2. `nolon/Skills/Views/Remote/ResourceDeleteTargetSheet.swift`
3. `nolon/Skills/Views/Remote/ResourceCatalogGridView.swift`
4. `nolon/Skills/Views/Remote/RemoteSkillCardView.swift`
5. `nolon/Skills/Views/Remote/RemoteWorkflowCardView.swift`
6. `nolon/Skills/Views/Remote/RemoteMCPCardView.swift`
7. `nolon/Skills/Views/Remote/ResourceCenterView.swift`
8. `nolon/Skills/Views/Core/MainSplitView.swift`

## 测试策略
1. 先补 `ResourceDeletionCoordinator` BDD 单测（红灯）。
2. 最小实现后转绿。
3. 回归执行：
- `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug test -only-testing:nolonTests/ResourceDeletionCoordinatorTests`

## 已知风险
1. 删除结果提示当前按 slug 展示，未显示 displayName。
2. UI 自动化点击三点菜单在当前系统会话存在事件稳定性问题，截图以可复现流程状态为主。
