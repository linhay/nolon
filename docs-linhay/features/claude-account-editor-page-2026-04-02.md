# Claude Code 账号编辑页（2026-04-02）

## 背景
- 当前 Claude 账号页支持迁移、导入、激活，但缺少“编辑已有账号”的入口。
- 用户在账号密钥轮换、Base URL 变更时只能重新导入或手改文件，维护成本高。

## 目标
1. 在 Claude 账号卡片提供“编辑”操作。
2. 提供账号编辑弹窗，支持修改：账号名、鉴权类型、密钥、Base URL。
3. 保存后落盘到 Claude 账号快照；若编辑的是当前激活账号，同步写回 `settings.json`。

## 非目标
1. 本次不新增 Claude 账号“删除”能力。
2. 本次不调整 Claude 账号导入与迁移策略。

## BDD 验收场景
1. Given Claude 账号卡片已渲染，When 打开卡片菜单，Then 可见“编辑”动作。
2. Given 用户点击“编辑”，When 弹窗打开，Then 展示当前账号的可编辑字段。
3. Given 用户清空密钥或 Base URL，When 点击保存，Then 阻止保存并展示错误提示。
4. Given 用户保存有效修改，When 提交成功，Then 弹窗关闭且账号列表刷新为最新内容。
5. Given 被编辑账号是当前激活账号，When 保存成功，Then Claude `settings.json` 同步更新为新配置。

## 实现约束
1. 复用现有 `ProviderUsage` 统一卡片动作体系（`AccountCardActionID.edit`）。
2. 编辑状态集中在 `ProviderUsageAccountsViewModel.ClaudeState`，避免打散到 View 层。
3. 账号持久化通过 `ClaudeAccountManager.updateAccount`，激活账号额外执行一次激活写回。

## 测试要求
1. `ProviderUsageUnifiedAccountsPipelineTests` 新增/更新：
   - Claude 卡片菜单包含 `.edit`。
   - 触发 `.edit` 动作后进入 Claude 编辑态并携带正确账号 ID。
2. 全量 `nolon-tests` 需通过。

## 进展更新（2026-04-02，cc-switch 对齐）
1. Claude 账号编辑页可配置项对齐 `cc-switch`：
   - `ANTHROPIC_MODEL`
   - `ANTHROPIC_DEFAULT_HAIKU_MODEL`
   - `ANTHROPIC_DEFAULT_SONNET_MODEL`
   - `ANTHROPIC_DEFAULT_OPUS_MODEL`
2. 保持兼容读取旧字段：`ANTHROPIC_SMALL_FAST_MODEL`（仅回退读取，不再作为首选写入）。
3. 默认值策略（Cloud Code）：
   - `ANTHROPIC_MODEL`: `gpt-5`
   - `ANTHROPIC_DEFAULT_HAIKU_MODEL`: `gpt-5(minimal)`
   - `ANTHROPIC_DEFAULT_SONNET_MODEL`: `gpt-5(medium)`
   - `ANTHROPIC_DEFAULT_OPUS_MODEL`: `gpt-5(high)`
4. 数据落盘要求：
   - 账号配置持久化到 `nolon.sqlite3`（claude_accounts 扩展字段）。
   - 激活账号写回 `settings.json` 的 `env` 同步上述字段。

## 进展更新（2026-04-02，账号级字段补齐）
1. 账号级可配置项已补齐到 cc-switch 同层：新增 `ANTHROPIC_REASONING_MODEL` 编辑与持久化。
2. 账号编辑页现在完整支持：`ANTHROPIC_MODEL`、`ANTHROPIC_REASONING_MODEL`、`ANTHROPIC_DEFAULT_HAIKU_MODEL`、`ANTHROPIC_DEFAULT_SONNET_MODEL`、`ANTHROPIC_DEFAULT_OPUS_MODEL`。
3. 激活账号写回 `settings.json` 时：若 `ANTHROPIC_REASONING_MODEL` 为空则移除该键，避免污染配置。
