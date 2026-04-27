# Claude Usage Empty State Outcome Suppression

## 背景

在 `Claude Code / Usage` 页面里，当本地没有任何 Claude 账号时，页面会同时出现：

1. `No Claude accounts` 空状态卡
2. `Failed to load usage` / `No active account for claude. Please sign in.` 错误卡

这两个状态来自不同数据源，但在“无账号”场景下同时出现会造成重复提示。

## 验收场景

### 场景 1：无 Claude 账号

- Given `claudeAccounts.isEmpty == true`
- And usage outcome 为 `ProviderUsageError.missingAccount(.claude)`
- When 渲染 Claude Usage 页面
- Then 页面只显示 `No Claude accounts` 空状态
- And 不显示 `missingAccount(.claude)` 对应的 usage 错误卡

### 场景 2：有 Claude 账号但 active account 丢失

- Given `claudeAccounts.isEmpty == false`
- And usage outcome 为 `ProviderUsageError.missingAccount(.claude)`
- When 渲染 Claude Usage 页面
- Then 仍然显示 usage 错误卡，帮助诊断账号激活状态异常

## 实现约束

- 仅在 Claude 页面处理该互斥逻辑
- 不影响 Gemini/Antigravity 现有空状态与 outcome 展示规则
- 不隐藏其他 Claude usage 错误，例如网络错误、解析错误、服务端错误
