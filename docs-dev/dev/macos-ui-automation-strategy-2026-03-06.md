# macOS UI 自动化落地方案（2026-03-06）

## 关联文档
- `docs-dev/dev/resource-center-delete-implementation-2026-03-04.md`

## 背景
当前 `nolon` 的资源中心、远程技能安装/删除、仓库切换等功能已具备较完整的单元测试与集成测试覆盖，但在“用户真实点击路径是否能稳定触发业务链路”这一层，仍需要 macOS UI 自动化作为回归门禁。

本方案只解决 `nolon` 自身的 UI 自动化，不覆盖第三方 app 的跨应用控制。

## 目标
1. 使用 Apple 官方支持的 `XCUITest` 作为主回归链路。
2. 避免把回归稳定性建立在系统菜单、裸 `AXUIElement`、AppleScript 之上。
3. 为资源中心提供可重复、可隔离、可在 CI/本地复跑的端到端场景。
4. 把“UI 自动化需要的特殊入口”限制在 `UITestSupport` 和测试模式开关内，不污染正常产品逻辑。

## 非目标
1. 不以 AppleScript 作为正式回归方案。
2. 不为每个 UI 细节做截图式快照测试。
3. 不依赖本机真实 `~/.nolon` 数据。

## 方案选择

### 主方案：XCUITest
适用原因：
1. `nolon` 是自有 SwiftUI macOS app，可以直接加 UI Test target。
2. 可通过 `XCUIApplication`、`XCUIElementQuery` 稳定驱动窗口、按钮、搜索框、弹窗。
3. 与 Xcode 构建、测试报告、失败截图、重试流程天然兼容。

### 辅助方案：Accessibility Inspector
用途：
1. 检查 SwiftUI 控件是否正确暴露 `accessibilityIdentifier`。
2. 在 UI test 找不到控件时，验证 AX 树而不是盲猜查询方式。

### 明确不用作主链路的方案
1. `AXUIElement`：可用于底层排障，但不作为主回归手段。
2. AppleScript / `System Events`：仅适合临时脚本，不适合作为长期测试资产。
3. Appium Mac2：当前项目没有跨语言 WebDriver 诉求，额外引入一层没有必要。

## 总体设计

### 1. 正式 UI Test Target
使用独立 `nolonUITests` target，而不是把 UI 自动化塞进普通单元测试 target。

要求：
1. 使用 `XCUIApplication(bundleIdentifier: "nolon.overloaded.com")` 启动宿主 app。
2. 所有 UI 用例放在 `nolonUITests/`。
3. UI test 只负责“用户路径 + 最终可见结果/落盘结果”，不重复验证底层删除编排细节。

### 2. UITestSupport 开关
所有测试专用入口都通过环境变量控制，统一收口在：
- `nolon/Skills/Infrastructure/UITestSupport.swift`

当前应支持的能力：
1. 跳过 onboarding
2. 启动后自动打开资源中心
3. 指定初始仓库
4. 指定初始搜索词
5. 指定 fixture global skill slug
6. 暴露测试专用 direct delete 按钮
7. 自动确认删除
8. 指向临时 `NOLON_HOME`

原则：
1. 默认关闭
2. 仅在 `NOLON_UI_TEST_MODE=1` 时启用
3. 测试开关不进入生产路径判断之外的业务逻辑分支

### 3. 稳定选择器策略
禁止主链路依赖：
1. 中文文案
2. 菜单层级文本
3. 屏幕坐标点击

必须做法：
1. 关键控件提供稳定 `accessibilityIdentifier`
2. SwiftUI 卡片、搜索框、仓库切换项、安装/删除按钮、确认按钮均使用固定 identifier
3. 测试查询优先使用 identifier，其次才考虑 label

建议覆盖的控件：
1. 资源中心入口
2. 仓库列表项
3. 搜索框
4. 远程技能卡片
5. 安装按钮
6. 删除按钮
7. 删除确认按钮
8. 删除结果提示

### 4. 测试专用直达入口
资源中心里存在三点菜单、sheet、确认弹层等多层交互，这些层在 macOS 上经常受菜单桥接和焦点切换影响。

因此需要一个严格受控的测试入口：
1. 仅在 UI test 模式下显示
2. 直接调用正式 `onDeleteSkill` 业务链路
3. 不绕过删除编排器、不绕过 ViewModel
4. 仅绕过脆弱的菜单交互

当前删除场景采用此策略是合理的，因为测试目标是：
1. UI 能触发删除
2. 删除后卡片状态变化正确
3. 临时 `NOLON_HOME/skills/<slug>` 被删除

而不是验证系统菜单动画和桥接本身。

### 5. 测试数据隔离
每条 UI 用例使用临时目录作为 `NOLON_HOME`。

准备步骤：
1. 创建临时根目录
2. 写入 `skills/gemini/SKILL.md`
3. 注入环境变量 `NOLON_HOME=<tempRoot>`
4. 可选写入 provider fixtures

断言：
1. 只检查临时目录
2. 不读取真实 `~/.nolon`
3. 不依赖用户本机历史状态

## 建议分层

### 单元/集成测试层
负责验证：
1. 删除计划构造
2. provider 作用域解析
3. 全局缓存删除
4. 安装态刷新
5. ViewModel 状态转换

### UI 测试层
负责验证：
1. app 能按预期启动到资源中心
2. 搜索结果卡片可见
3. UI 删除入口可触发
4. 删除完成后卡片消失或状态更新
5. 临时目录中的技能被删除

这样可以避免把所有失败都归因给 UI 自动化。

## 首批必跑场景

### 场景 1：删除全局技能
Given:
1. UI test 模式开启
2. `NOLON_HOME/skills/gemini` 已存在
3. 资源中心启动到 `globalSkills`
4. 初始搜索词为 `gemini`

When:
1. 点击测试专用删除入口
2. 确认删除

Then:
1. `NOLON_HOME/skills/gemini` 不存在
2. 结果提示出现
3. 卡片消失或显示未安装

### 场景 2：搜索远程技能
Given:
1. 启动到资源中心
2. 初始仓库为 `globalSkills`

When:
1. 输入 `gemini`

Then:
1. `gemini` 卡片可见
2. 搜索框内容正确

### 场景 3：安装全局技能
Given:
1. `NOLON_HOME/skills/gemini` 不存在

When:
1. 点击安装

Then:
1. `NOLON_HOME/skills/gemini` 出现
2. 卡片显示已安装

## 实施顺序
1. 先把 `nolonUITests` target 跑通
2. 先完成“删除全局 gemini”这条最关键路径
3. 再补搜索和安装回归
4. 最后再考虑三点菜单/上下文菜单等高脆弱性交互的覆盖

## 稳定性要求
1. 统一使用 `waitForExistence(timeout:)`
2. 避免固定 `sleep`
3. 查询顺序固定：identifier -> fallback label
4. 所有 fixture 都可重复初始化
5. 测试失败时保留 `xcresult` 以便回溯 UI 树与截图

## 风险与应对
1. 风险：SwiftUI 控件未正确暴露 AX 节点
   - 应对：先用 Accessibility Inspector / `app.debugDescription` 校验，再调整 identifier
2. 风险：菜单/弹层在 macOS 上焦点不稳定
   - 应对：关键业务路径使用测试专用入口，不把菜单桥接作为主门禁
3. 风险：真实用户数据污染测试结果
   - 应对：强制使用临时 `NOLON_HOME`
4. 风险：远程数据不稳定
   - 应对：对关键场景使用 fixture 兜底，远程列表只验证最小必要行为

## 完成定义
1. `nolonUITests` 可由 `xcodebuild test` 执行
2. 全局 `gemini` 删除 UI case 稳定通过
3. 失败时能从 `xcresult` 和控件 identifier 快速定位问题
4. 不依赖用户真实环境即可复跑
