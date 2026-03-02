# Codex 账号与用量 Tab 命名与操作区更新（2026-03-02）

## 目标
- 将 Codex 相关 Provider 的 `用量` Tab 统一命名为 `账号与用量`。
- 在 Codex 用量页顶部提供固定三操作入口：`刷新 | 登录 | 导入`。

## 范围
- 包含：`codex`、`codexXcode` 两类 Provider 的 Tab 文案与用量页头部操作区。
- 不包含：账号刷新底层逻辑重构、非 Codex Provider 的用量页交互改造。

## 交互与行为规则
1. Tab 文案规则：
   - `codex`/`codexXcode`：显示 `账号与用量`。
   - 其他 Provider：保持 `用量`（`tab.usage`）不变。
2. Codex 用量页头部按钮顺序固定：`刷新 | 登录 | 导入`。
3. `刷新`语义为“全部刷新”，触发当前 Codex 多账号的全量刷新链路（沿用现有 `load()` 内并行刷新逻辑）。
4. 非 Codex Provider 保持原有登录入口与菜单交互，不受本次变更影响。

## BDD 验收
1. Given 当前 Provider 为 Codex，When 查看侧栏 Tab，Then `用量`显示为`账号与用量`。
2. Given 当前 Provider 为 CodexXcode，When 查看侧栏 Tab，Then `用量`显示为`账号与用量`。
3. Given 当前 Provider 为 Codex，When 进入用量页头部，Then 按钮顺序为 `刷新 | 登录 | 导入`。
4. Given 当前 Provider 为非 Codex，When 查看用量页与 Tab，Then 文案与交互保持现状。

## 影响实现点
- `ProviderContentTabType`：新增按 Provider 解析 usage 名称能力。
- `ProviderUsageView`：新增可测试的头部动作枚举并切换 Codex 头部按钮布局。
- `Localizable.xcstrings`：新增 `tab.account_usage`、`codex.accounts.refresh_all`。
