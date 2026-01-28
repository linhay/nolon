# Skill: macos-app-development

本 Skill 用于规范 macOS 特有的开发模式，确保应用在窗口管理、外部事件响应（URL Scheme）和 UI 状态同步方面表现一致。

## 触发条件
- 修改 `App` 结构体或入口配置文件（如 `nolonApp.swift`）。
- 注册、修改或处理自定义 URL Scheme (`nolon://`, `nln://`)。
- 涉及多窗口逻辑或 Window 场景切换时。

## 规则 (Do)

### 1. 窗口管理与单实例
- **优先使用 `Window` 而非 `WindowGroup`**: 除非应用明确需要支持打开多个独立文档，否则优先使用 `Window("Title", id: "id")` 以确保应用保持单窗口实例。
- **配置 `handlesExternalEvents`**: 
    - 使用 `WindowGroup` 时，注意其默认会为外部事件（如 URL）打开新窗口。
    - 若要防止 URL 触发多窗口，请在主场景上设置 `.handlesExternalEvents(matching: [])` 并通过 `AppDelegate` 集中分发。

### 2. URL Scheme 处理
- **双向监听**: 
    - 优先在 `AppDelegate` 的 `application(_:open:)` 中接收 URL，以确保应用在后台或冷启动时也能捕获事件。
    - 配合 SwiftUI 的 `.onOpenURL` 使用时，注意二者的执行顺序和冲突（尤其是单窗口场景下）。
- **集中管理**: 使用单例（如 `URLSchemeHandler`）管理 `pendingURL`，避免各视图组件分散处理原始 URL 字符串。

### 3. UI 状态同步
- **防止 @State 缓存**: 
    - SwiftUI 内部的 `@State` 在视图重用或场景重绘时可能保留旧值。
    - 在 Sheet 或弹窗中，务必在 `.onAppear` 中显式调用 ViewModel 的刷新方法，确保读取到最新的全局状态。

### 4. 异步任务与错误处理
- **使用 `.task(id:)` 处理重载**: 依赖某个状态（如 `repository`）加载数据时，优先使用 `.task(id: someState)`。它会自动管理任务生命周期（取消旧任务，启动新任务）。
- **忽略取消错误**: 在异步加载函数中，务必捕获并静默忽略 `CancellationError` 和码为 `.cancelled` 的 `URLError`。禁止将这类错误显示在 UI 上。

### 5. UI 模式一致性 (Premium UX)
- **卡片风格统一**: 所有的 Grid 卡片（如 `WorkflowCardView`, `McpServerCard`）应遵循统一规范：
    - `VStack(alignment: .leading, spacing: 12)` 布局，`padding(16)`。
    - 交互：添加 `@State private var isHovered = false`，实现 `scaleEffect` (1.02) 和阴影增强。
    - 结构：Header (标题+Badge)、Description (最大高度占据剩余空间)、Footer (状态信息+操作按钮)。

## 禁令 (Don't)
- 禁止在 `WindowGroup` 上匹配通配符 `"*"`，这在 macOS 上极易导致重复窗口。
- 禁止在视图的 `init` 方法中执行耗时或涉及副作用的操作（如设置 `pendingImportURL = nil`），应移至 `Task` 或 `onAppear`。

## 验证 (Validation)
- 点击协议链接测试：
    1. 应用是否激活且未产生多余窗口。
    2. 相关弹窗或界面是否正确显示并填充了数据。
- 检查控制台是否有 `Publishing changes from within view updates is not allowed` 的警告。
