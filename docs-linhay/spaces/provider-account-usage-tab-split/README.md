# Provider 详情页账号与用量双 Tab（2026-04-16）

## 背景

- 当前 provider 详情页中，`.accounts` 与 `.usage` 两个路由都落到同一个 `ProviderUsageView`。
- 现有页面仍是“账号区 + 历史 Token 消耗”线性同页展示，导致路由语义与页面内容不一致。
- 2026-04-15 的边界讨论已经把底层状态和加载入口拆到可支持双 tab 的程度，但 UI 仍停留在综合页。

## 目标

1. 在 provider 详情页中，把“账号”和“用量”拆成两个独立 tab。
2. `Accounts` tab 只展示账号管理相关内容，不再内嵌 token trend。
3. `Usage` tab 只展示 token trend / intraday drilldown，不再重复渲染账号卡片。
4. 保持底层 usage 数据链与 root store 复用，不重做 provider usage 事实源。

## 范围

- 包含：
  - 首批落地 `codex`、`claude`、`gemini`、`antigravity` 四类 provider 的详情页双 tab
  - provider 详情页 tab 列表与顺序
  - `ProviderUsageView` 的内容模式拆分
  - `ProviderUsageRootViewModel` 的页面标题与加载入口按 tab 分流
  - `claude` token trend / intraday drilldown 的本地 session 日志聚合
  - 相关单元/配置测试
- 不包含：
  - `Tools -> Accounts` 全局账号中心的导航结构改造
  - provider usage 底层 session / cost 数据源重写
  - `Sessions` / `Runtime` / `Binary` 既有 tab 的交互改造

## 默认决策

1. 当前仅对“已有真实 token trend / intraday usage 区块”的 provider 自动补出 `accounts` tab，首批为 `codex`、`claude`、`gemini`、`antigravity`。
2. `accounts` tab 放在 `usage` tab 之前。
3. `Accounts` tab 使用账号域加载入口；`Usage` tab 使用 usage 域加载入口；全页编排入口仅保留给需要综合加载的场景。
4. `claude` 的 `Usage` 页不走 web usage API 拼接，而是扫描本地 Claude session 日志并按日 / 分时聚合 token trend。
5. `codexXcode` 继续不展示 `accounts` tab，因为账号与用量仍由 Xcode 管理。
6. `codex` 的 `Usage` 页当前产品语义定为 `global local usage`：展示本机全局本地会话聚合，不承诺与当前账号或上游统计同源。

## BDD 验收

1. Given provider 为 `codex`、`claude`、`gemini` 或 `antigravity`，When 渲染 provider 详情 tab，Then 出现独立的 `Accounts` 与 `Usage` 两个 tab，且 `Accounts` 位于 `Usage` 之前。
2. Given provider 为 `copilot` 或其他仅 usage 入口 provider，When 渲染 provider 详情 tab，Then 继续只显示 `Usage`，不新增 `Accounts`。
3. Given 用户进入 `Accounts` tab，When 页面渲染完成，Then 只展示账号管理相关内容，不显示 `历史 Token 消耗` 区块。
4. Given 用户进入 `Usage` tab，When 页面渲染完成，Then 只展示 token trend / intraday drilldown，不显示账号卡片区。
5. Given 用户首次进入 `Accounts` tab，When 触发页面加载，Then 只走账号域加载入口，不要求同时刷新 usage。
6. Given 用户首次进入 `Usage` tab，When 触发页面加载，Then 只走 usage 域加载入口，不要求同时刷新账号域。
7. Given provider 为 `claude`，When 用户进入 `Usage` tab，Then 页面展示基于本地 Claude session 日志聚合的 token trend / intraday 数据，而不是空 usage 页。
8. Given provider 为 `codexXcode`，When 渲染 provider 详情 tab，Then 仍不出现 `Accounts` tab。
