# 2026-04-20 Codex Sessions Group Header Rail 执行计划

## 目标
1. 把 group header 收口成和单会话 row 一致的两层结构：标题在上，subtitle rail 在下。
2. 统一组头与单会话的菜单视觉，只保留点点点入口。
3. 给组级菜单补齐复制本组线程 ID 与打开关联文件夹。
4. 抬高组头与会话标题字号，提升大列表浏览可读性。

## 范围
- 只改 `Codex Sessions` 的 section header / row typography / group menu。
- 不重做扫描、缓存、排序和详情数据模型。
- 不改变现有整组 rewrite / share 的业务语义。

## 执行步骤
1. 重构 `UnifiedCodexSessionViews` 的 section header：
   - 移除左侧 icon
   - 标题独立成第一行
   - usage / badge / 状态 / 路径 合并为 subtitle rail
2. 统一组头菜单入口：
   - 改为 `EllipsisMenuButton`
   - 保留已有 group action
   - 新增复制线程 ID 与打开文件夹
3. 在 `CodexSessionsTabViewModel` 提供 section 级完整线程 ID 与有效目录路径。
4. 在 `CodexSessionsTabView` 接线 pasteboard / Finder 动作。
5. 提升 section title 与 row title 字号。
6. 跑 `CodexSessionsCardSnapshotTests` 做视觉回归验证。

## 风险
- subtitle rail 采用 `Text` 拼接后，SwiftUI 对可选 `help`/`Text` 的类型推断更容易报编译错误，需要显式拆分分支。
- section 的 `titleSecondaryText` 在 provider grouping 下不一定是目录路径，需要在 ViewModel 先过滤掉无效路径。

## 验证命令
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`
