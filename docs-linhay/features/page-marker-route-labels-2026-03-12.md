# 页面标签统一标记（2026-03-12）

## 背景
- 当前 Nolon 的主页面与子页面缺少统一、稳定、可见的页面名标记。
- 联调、截图、缺陷沟通时，经常需要额外确认“当前是哪一页 / 哪个子页”。

## 目标
- 在主页面与当前子页面上统一显示单个定位图标按钮。
- 页面标签由容器状态推导，避免每个业务页手工维护一套文案。
- 新页面后续只需复用统一组件与解析器即可接入。
- 页面标签仅在 Debug 构建中显示，避免进入正式用户界面。
- 定位图标按钮点击即可复制完整定位文本，方便联调和缺陷沟通时直接粘贴。
- 定位图标按钮使用高对比背景色，保证在复杂页面上也容易识别。
- 定位图标按钮以 overlay 方式悬浮在视图上，不应占用页面布局高度。
- 页面标签额外显示调用点调试元信息：`#file #line #function`。
- 页面标签默认关闭，通过菜单栏 `Debug -> Show Page Markers` 手动开启。
- Debug 模式下记住 `Show Page Markers` 的上次选择，避免每次重启重复开启。
- 资源卡片与账号卡片也展示同风格定位按钮。
- 我们自定义的页面类型与卡片类型通过统一协议接入，减少后续遗漏与重复 modifier。
- 侧边栏面板（Provider Sidebar / Resource Repository Sidebar / Resource Tab Sidebar / Plugin Navigation）也需显示定位图标按钮。
- `RemoteSkillCardView`、`RemoteWorkflowCardView`、`RemoteMCPCardView` 显式遵守 `DebugPageLocatable`，保证卡片类型本身可追踪。

## 范围
- `Accounts`
- `Plugin Management`
- Provider 页面
- Provider 子页面（如 `Skills` / `Usage` / `Runtime`）
- `Resource Center`
- `Resource Center` 子页面（如 `Skills` / `Workflows` / `MCPs`）

## 实现备注
- `build.sh` 现已作为默认门禁脚本，默认使用 `nolon-app` scheme，避免 App 层 SwiftUI / Observation 问题被 `nolon` scheme 漏检。
- 默认门禁执行 `Release build + Debug unit tests`，其中测试默认限定到 `nolonTests`；`nolonUITests` 改为显式 `TEST_SCOPE=ui` 触发，避免环境波动导致日常门禁误伤。
- `RemoteRepositorySidebarViewModel`、`NolonAccountsViewModel`、`AppCommandState` 等 `@MainActor @Observable` 类型在析构阶段需要避免触发 back-deploy 主线程执行器释放路径；当前通过显式 `nonisolated deinit {}` 与视图生命周期清理任务配合规避。
- 账号卡片在 `tapBehavior == .activate` 时，主 CTA 会由 `AccountCardViewDataMapper` 去重，避免点击整卡和按钮产生重复激活动作；此时保留右键菜单动作用于调试复制。

## 非目标
- 不引入新的导航结构。
- 不把页面标签做成可交互 breadcrumb。
- 不修改现有页面主标题和 toolbar 行为。

## BDD 验收
1. Given 当前选中 `Accounts`
   When 页面渲染
   Then 顶部可见单个 `Accounts` 定位图标按钮

2. Given 当前选中 provider `Codex`
   And 当前 tab 为 `Usage`
   When 详情页渲染
   Then 顶部可见 `Codex / 账号与用量 / #file #line #function` 定位图标按钮

3. Given 当前选中 provider `Claude`
   And 当前 tab 为 `Skills`
   When 中间导航页渲染
   Then 顶部可见 `Claude / #file #line #function` 定位图标按钮

4. Given 当前打开 `Resource Center`
   And 当前 tab 为 `MCPs`
   When 页面渲染
   Then 顶部可见 `Resource Center / MCPs / #file #line #function` 定位图标按钮

5. Given 页面没有 provider 或 tab
   When 空状态渲染
   Then 定位图标按钮只显示当前可确定的层级，不展示空占位文本

6. Given 当前为 Release 构建
   When 页面渲染
   Then 不显示定位图标按钮

7. Given 当前为 Debug 构建
   And 定位图标按钮显示为 `Codex / 账号与用量 / #ProviderDetailGridView.swift #125 #body`
   When 用户点击定位图标按钮
   Then 可得到完整定位文本 `Codex / 账号与用量 / #ProviderDetailGridView.swift #125 #body`

8. Given 当前为 Debug 构建
   And 标签功能已开启
   When 页面渲染
   Then 定位图标按钮文本中额外显示 `#file #line #function`

9. Given 当前为 Debug 构建
   And 用户尚未从菜单栏开启 `Show Page Markers`
   When 页面渲染
   Then 不显示定位图标按钮

10. Given 当前展示账号卡片或资源卡片
    And 标签功能已开启
    When 卡片渲染
    Then 卡片右上角显示紧凑版定位图标按钮，点击后复制该卡片定位文本

11. Given 新增一个自定义页面类型或卡片类型
    When 该类型遵守统一的 Debug 定位协议
    Then 只需提供定位项即可复用统一样式、复制行为与 debug 开关

12. Given 当前为 Debug 构建
    And 用户手动开启了 `Show Page Markers`
    When 应用重启后再次进入 Debug 构建
    Then 仍保持上次的开启状态

13. Given 用户浏览侧边栏面板
    When 页面渲染
    Then Provider Sidebar、Resource Repository Sidebar、Resource Tab Sidebar、Plugin Navigation 都显示定位图标按钮

14. Given 页面启用了定位图标按钮
    When 页面渲染
    Then 定位图标按钮悬浮在内容上层且不改变内容原有布局高度

15. Given 用户在 `Repository Sidebar` 里对 Git 仓库行执行 `Copy Page Marker`
    And 行内展示名称为 `owner@repo`
    When 复制定位文本
    Then 结果包含 `Repository Sidebar / owner@repo / #file #line #function`

## 2026-03-13 补充
- `RemoteRepositorySidebarView` 的页面 marker 名称统一改为复用 `repositoryDisplayName(_:)`，避免 Git 仓库右键复制时回退到原始 `repo.name`，导致与列表展示名称不一致。
