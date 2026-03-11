# Provider Vendor Categories And Nolon Accounts

## 背景
- 现有 `ProviderKind` 只有 `vendor / project` 两层，无法区分“原始厂商”和“集成厂商”。
- 账号能力目前主要散落在单个 Provider 的 Usage 页面，缺少 `nolon` 全局聚合入口。
- `pi` 需要按 `badlogic/pi-mono/packages/coding-agent` 的官方文档正式接入，而不是使用占位路径。

## 目标
1. 在 `vendor` 下新增稳定的二级分类：
   - 原始厂商：`codex`、`gemini`、`claude`
   - 集成厂商：`codexXcode`、`copilot`、`opencode`、`antigravity`、`pi`
2. 在侧边栏 `Tools` 区新增全局 `Accounts` 页面，聚合支持账号状态或账号管理的 Provider。
3. 正式接入 `pi` 模板：
   - CLI: `pi`
   - 全局根目录：`~/.pi/agent`
   - 全局 skills：`~/.pi/agent/skills`
   - 项目级根目录：`<project>/.pi`
   - 项目级 skills：`<project>/.pi/skills`
   - 认证文件：`~/.pi/agent/auth.json`
   - 原生 MCP：当前官方文档标记为 `No MCP`

## 非目标
- 不改变 `ProviderKind.project` 的语义。
- 不重写或迁移底层 Provider-specific auth 存储格式。
- 不在本次实现 `openclaw` 模板。
- 不要求 `pi` 在本次支持完整登录/切换/删除；只接入只读账号摘要。
- 不再保留 `PiAccountSummaryCard` 这种 Provider 专属碎片卡片实现。

## 官方事实来源
- `https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent`
- `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/settings.md`
- `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md`
- `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/providers.md`

## 设计约束
1. `vendor / project` 继续保留为一级分类。
2. `vendorCategory` 仅对 `kind == .vendor` 的 Provider 生效。
3. 模板能力必须显式化，至少包含：
   - `vendorCategory`
   - `supportsNativeMcpConfig`
   - `supportsAccounts`
   - `supportsMultiAccount`
   - `secondaryResourceLabel`
4. `pi` 的 secondary resource 文案使用 `Prompts`，不再显示为 `Workflow`。
5. `Accounts` 页为 `nolon` app 层聚合入口，底层继续复用 `libs/Providers` 的能力。

## 验收场景
1. Given 旧版 vendor provider 缺少 `vendorCategory`，When 应用升级加载配置，Then 按模板默认值自动补齐并持久化。
2. Given 旧版 project provider 缺少 `vendorCategory`，When 应用升级加载配置，Then 保持 `nil` 且不受影响。
3. Given Add Provider 弹窗，When 用户选择 vendor 模板，Then 模板按“原始厂商 / 集成厂商”分组显示。
4. Given Sidebar 中存在多个 vendor provider，When 渲染列表，Then 固定按 `Original Vendors -> Integrated Vendors -> Projects -> Tools` 顺序展示。
5. Given Onboarding Provider 选择页，When 展示模板，Then 模板按 `vendorCategory` 分组。
6. Given 选择 `Accounts` 工具页，When 加载全局账号中心，Then 只展示支持账号状态或账号管理的 Provider。
7. Given `pi` provider 已配置，When 全局 `Accounts` 页加载，Then 能从 `~/.pi/agent/auth.json` 生成只读账号摘要。
8. Given `pi` provider，When 浏览 Provider 详情或编辑视图，Then secondary resource 文案显示为 `Prompts`，且 MCP 区明确显示不支持原生配置。
9. Given 某 Provider 聚合加载失败，When `Accounts` 页刷新，Then 仅该 Provider 卡片报错，不影响其它 Provider。
10. Given `codexXcode` provider，When 打开 `Tools -> Accounts`，Then 不展示账号卡片（归属于集成厂商，账号页仅显示原始厂商账号）。
11. Given `Tools -> Accounts` 展示多个支持用量的 Provider，When 刷新后，Then 每个卡片展示统一的聚合用量摘要（总数/成功数/失败数/最近更新时间），不再嵌入完整 Usage 管理页面。
12. Given 进入 `Tools -> Accounts`，When 渲染三栏结构，Then 不再出现中间“账号”单项 tab，仅保留左侧工具入口与右侧账号详情页。
13. Given Accounts 页与 Usage 页都需要展示账号卡片，When 渲染 Codex / Claude / 聚合摘要 / Loading Skeleton，Then 统一复用同一个账号卡片表面组件与选中态样式策略。

## 默认决策
- 未知 vendor provider 的缺失分类默认迁移为 `integrated`。
- `pi` 在全局 `Accounts` 页本次仅提供只读状态，不开放登录、切换、删除。
- `Accounts` 页中的无账号能力 Provider 默认不展示。
- 侧边栏组内顺序保留用户现有顺序，分类迁移不触发重排。
