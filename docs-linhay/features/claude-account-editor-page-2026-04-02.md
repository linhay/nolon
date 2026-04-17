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

## 进展更新（2026-04-15，编辑页重构）
1. Claude 账号新增/编辑页需要从“单层 `Form` 直出”重构为有信息架构的编辑器：
   - 顶部标题区：标题、副标题、错误提示、关闭动作。
   - 基础信息区：账号名、鉴权类型。
   - 连接配置区：Credential、Base URL 与必要说明。
   - 模型映射区：主模型、Reasoning、Haiku、Sonnet、Opus，并提供一键恢复 Cloud Code 默认值。
   - 底部操作区：取消 / 保存，保存按钮需体现可用状态。
2. 视觉目标：
   - 不再使用当前松散的原生 `Form` 堆字段。
   - 改为卡片化分区、滚动容器和更明确的字段层级。
   - 关键说明文案直接贴近字段，减少“填完才知道要求”的心智负担。
3. 行为约束：
   - 新建账号与编辑账号共用同一套 sheet，但标题、副标题、主按钮文案按模式切换。
   - 新建账号时若用户改写模型映射，保存后必须完整持久化到账号快照，不能退回默认值。
   - 编辑当前激活账号后，现有“同步写回 `settings.json`”行为保持不变。
4. 测试要求补充：
   - 增加 Claude 账号编辑器快照测试，覆盖 create / edit 两种主要布局。
   - 增加状态/集成测试，覆盖“新建账号时自定义模型映射可持久化”这一回归点。

## 进展更新（2026-04-15 ~ 2026-04-16，CC switch JSON 区与官方空映射）
1. Claude 编辑页增加一块对齐 `cc-switch` 的 JSON 编辑区，并升级为“双向联动”：
   - JSON 区聚焦 Claude `env` 片段，不展示无关根字段。
   - 表单字段变化会实时重写 JSON。
   - 用户直接编辑合法 JSON 时，会反向更新表单草稿。
   - 提供 `Format JSON` 动作，统一格式化到实际写回语义。
   - 不支持该表单无法完整表达的额外根字段 / env 字段；遇到未知键或鉴权歧义时直接报错，不做静默吞字段。
2. Model Mapping 默认值策略调整为“按官方空值语义”：
   - 新建账号时，`ANTHROPIC_MODEL`、`ANTHROPIC_REASONING_MODEL`、`ANTHROPIC_DEFAULT_HAIKU_MODEL`、`ANTHROPIC_DEFAULT_SONNET_MODEL`、`ANTHROPIC_DEFAULT_OPUS_MODEL` 初始均为空。
   - 不再提供“恢复 Cloud Code 默认值”按钮。
   - 保存校验不再要求模型映射字段必填；仅 `Credential` 与 `Base URL` 必填。
3. 数据生成与写回约束：
   - 预览与实际写回保持同一份生成规则。
   - `ANTHROPIC_BASE_URL` 与当前鉴权字段始终输出。
   - 模型映射字段仅在值非空时写入；值为空时从 `settings.json` 的 `env` 中移除，不写入伪默认值。
   - 继续兼容读取旧字段 `ANTHROPIC_SMALL_FAST_MODEL`，但仅用于迁移读取，不再写回。
4. 测试要求补充：
   - Claude 编辑器快照测试需覆盖 JSON 预览区。
   - 新建账号默认草稿测试需验证模型映射字段为空。
   - Claude settings 写回测试需验证空模型字段不会落盘到 `env`。

## 进展更新（2026-04-17，Credential 明文展示）
1. 用户新增交互要求：Claude 账号编辑页中的 `Credential` 输入框不再使用密文遮罩，编辑态需直接展示明文值。
2. 2026-04-17 的 debate 结论（`docs-linhay/debate/20260417/provider-usage/20260417-claude-credential-plaintext-v01.md`）确认：
   - 当前“密文”现象仅来自 UI 层的 `SecureField`。
   - `credentialValue` 在草稿、JSON 预览、SQLite 持久化与激活写回链路中始终按明文字符串流转。
   - 存储加密属于独立安全增强议题，不作为本次 UI 修复前置条件。
3. 实现约束补充：
   - 本次只调整 `ClaudeAccountEditorSheet` 的 Credential 输入控件，不改动 `ClaudeAccount`、`ClaudeAccountManager` 与 `settings.json` 写回协议。
4. 测试要求补充：
   - `ClaudeAccountEditorSheetSnapshotTests` 需新增 BDD 回归测试，验证编辑态不存在 `NSSecureTextField`，且明文 credential 会出现在普通可编辑文本框中。
