# Codex HTTP 用量查询（2026-03-07）

## 目标
- 为 Codex 卡片增加可配置的 HTTP 用量查询能力。
- 复用现有 ProviderUsage 页面和展示模型。
- 未配置时保持当前 Codex CLI / 本地用量链路不变。

## 范围
- 包含：HTTP 请求配置、变量替换、JSON 映射、保存前测试请求、错误提示、Codex 接入。
- 不包含：脚本执行、多步请求、网页登录态、Cookie 抓取、其他 Provider 正式接入。

## 核心规则
1. `usageQuery` 跟随每张 Codex 卡存储，写入现有 auth 文件的 `nolon.usage_query`。
2. 查询顺序固定为：
   - 若当前 active 卡启用了显式 `usageQuery`，先执行 HTTP 查询
   - 若是 `chatgptAccount` 且未配置显式 `usageQuery`，运行时合成默认 ChatGPT HTTP 查询并优先执行
   - 其他场景继续走现有 CLI / 本地状态逻辑
3. HTTP 失败时：
   - 显式 `usageQuery` 失败时，不自动回退 CLI
   - 默认 `chatgptAccount` HTTP 查询失败时，自动回退 CLI / app-server 用量链路
   - 显式 HTTP 失败不覆盖上次成功结果，页面显示最近失败摘要
4. 首版只支持：
   - `GET` / `POST`
   - JSON 响应
   - 点路径与数组索引映射
5. 首版安全边界：
   - 仅允许 `https`
   - 默认要求与 `baseURL` 同源（`scheme + host + port`）
   - 禁止回环地址、私网地址和 `file://`

## 数据模型
`nolon.usage_query` 最小字段：
- `enabled`
- `timeoutSeconds`
- `request.method`
- `request.url`
- `request.headers`
- `request.body`
- `credentials.baseURL`
- `credentials.apiKey`
- `credentials.accessToken`
- `credentials.userID`
- `mapping.planPath`
- `mapping.creditsRemainingPath`
- `mapping.usageUsedPath`
- `mapping.usageTotalPath`
- `mapping.costTodayUSDPath`
- `mapping.costLast30DaysUSDPath`
- `mapping.errorMessagePath`

补充约束：
- `credentials.userID` / `{{userID}}` 严格对齐 Codex：执行阶段只读取持久化的 `tokens.account_id` 或顶层 `account_id`。
- 不在 HTTP usage query 执行阶段从 JWT claims 临时回退推导 `userID`。
- callback/import 流程若能从 token/callback 恢复账号标识，必须在生成 `auth.json` 时就把 `tokens.account_id` 写完整。
- 默认 `chatgptAccount` HTTP 模板不写回 `auth.json`，仅在运行时合成：
  - `GET {{baseURL}}/wham/usage`
  - 默认 `baseURL = https://chatgpt.com/backend-api`
  - headers:
    - `Authorization: Bearer {{accessToken}}`
    - `chatgpt-account-id: {{userID}}`
  - mapping:
    - `plan_type`
    - `credits.balance`
    - `rate_limit.primary_window.*`
    - `rate_limit.secondary_window.*`
- 刷新调度补充：
  - `chatgptAccount` 即使带有旧的 `lastSyncFailedAt / lastSyncFailureMessage`，也仍允许再次刷新；
  - 仅配置型卡片（API Key / Relay）在已有失败元数据时继续保留 `failed_before` 跳过策略。

## BDD 验收
1. Given relay 卡配置了 HTTP 余额接口，When 刷新用量页，Then 页面优先显示 HTTP 返回结果。
2. Given 官方 API key 卡未配置 `usageQuery`，When 刷新，Then 继续走现有 CLI / 本地状态逻辑。
3. Given `chatgptAccount` 未配置显式 `usageQuery`，When 刷新，Then 页面优先使用默认 ChatGPT HTTP 模板查询 `/wham/usage`。
4. Given 默认 ChatGPT HTTP 查询失败，When 页面刷新，Then 自动回退 CLI / app-server 结果。
5. Given `chatgptAccount` 上一次刷新失败并留下失败元数据，When 再次刷新，Then 不应因 `failed_before` 被跳过，而应继续尝试默认 HTTP。
6. Given `usageQuery` 返回 `used` 和 `total`，When 映射成功，Then 页面显示进度信息。
7. Given HTTP 返回 401，When 页面刷新，Then 显示错误摘要且不提示重新登录。
8. Given HTTP 返回 200 但核心字段缺失，When 映射失败，Then 不覆盖旧成功结果。
9. Given 测试请求使用草稿配置，When 点击测试按钮，Then 请求不落盘且结果仅在编辑器内反馈。

## 影响实现点
- `ProviderUsage`：新增 `CodexHTTPUsageQuery*` 模型与执行器。
- `CodexUsageDescriptor`：区分显式 HTTP 失败与默认 ChatGPT HTTP 失败的回退策略。
- `CodexAuthManager`：保存 / 更新 `nolon.usage_query`。
- `ProviderUsageViewModel`：支持草稿测试、旧成功结果保留和 HTTP 错误摘要。
- `CodexConfigEditorSheet`：新增 HTTP 用量查询配置区块和测试入口。
