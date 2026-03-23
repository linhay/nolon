# Codex 导出 sub2api 实现设计（2026-03-11）

## 目标
在不改变内部 auth 快照存储结构的前提下，新增一条“从现有 Codex 账号快照导出 sub2api JSON”的只读转换链路。

## 入口
1. UI：`ProviderUsageView` 的 Codex 多选工具条新增 `导出 sub2api`
2. ViewModel：新增 `exportSelectedCodexAccountsAsSub2API()`
3. 底层：`CodexAuthManager.exportAccountsAsSub2API(accountIDs:destinationURL:)`
4. CLI：`nolon codex auth export --format sub2api --output <path>`
5. 导入面板：`CodexImportSheet` 新增 `导出 ZIP / 导出 sub2api`

## DTO
新增独立导出模型文件，包含：
1. `Sub2APIExportPayload`
2. `Sub2APIAccount`
3. `Sub2APIExportResult`

固定字段：
1. `type = "sub2api-data"`
2. `version = 1`
3. `proxies = []`

## CLI 设计
命令：

```bash
nolon codex auth export --format sub2api --all --output /tmp/codex-sub2api.json
```

参数：
1. `--format sub2api`：当前仅支持该格式
2. `--output <path>`：必填
3. 目标选择三选一：
   - `--all`
   - `--account-id <uuid> ...`
   - `--email <email> ...`

返回：
1. 文本模式输出 provider / format / output_path / exported_count / skipped counts
2. `--json` 输出结构化 payload，供脚本消费

## 映射规则
### OAuth
来源：
1. `auth_mode = chatgpt` 或 `chatgptAuthTokens`
2. 或 `CodexAuthSummary.cardKind == .chatgptAccount`

输出：
1. `type = oauth`
2. `credentials.access_token <- tokens.access_token`
3. `credentials.refresh_token <- tokens.refresh_token`
4. `credentials.id_token <- tokens.id_token`
5. `credentials.expires_at <- expires_at/expiresAt`
6. `credentials.email <- email/user.email/nolon.account.email`
7. `credentials.chatgpt_account_id <- canonical account id`
8. `credentials.plan_type <- summary.plan`
9. `extra.openai_passthrough = true`
10. `extra.codex_cli_only = true`

### 官方 API Key
来源：
1. `auth_mode = apikey`
2. 且没有 `nolon.relay`
3. 或 `CodexAuthSummary.cardKind == .officialAPIKey`

输出：
1. `type = apikey`
2. `credentials.api_key <- OPENAI_API_KEY`
3. `extra.openai_passthrough = true`

### Relay
来源：
1. `CodexAuthSummary.cardKind == .relayProfile`
2. 或 `auth_mode = apikey` 且存在 `nolon.relay`

处理：
1. 不导出
2. 汇总到 `skippedRelayCount`
3. UI 成功提示显示跳过数量

## 错误语义
1. 未选中账号：沿用现有 no-selection 提示。
2. 选中账号找不到：底层抛稳定错误。
3. 导出后 `accounts.isEmpty`：抛 `所选账号中没有可导出的 sub2api 账号。`
4. 写盘失败：透传系统错误。

## 导入面板复用方案
为了避免要求用户“先导入再导出”，底层额外提供“从已校验候选项直接导出”的只读路径：

1. ZIP：
   - 输入：`[CodexImportValidationResult]`
   - 仅处理 `isValid && authJSONString != nil`
   - 将候选 JSON 写入临时 `auth/` 目录，再压成 ZIP
2. sub2api：
   - 输入：`[CodexImportValidationResult]`
   - 使用 `authJSONString` 构造 JSON/summary
   - 复用正式账号页相同的 relay / oauth / apikey 映射规则
3. ViewModel：
   - 复用 `codexImportCandidates` 的勾选状态
   - 保存路径由 `NSSavePanel` 决定
   - 导出成功后不关闭导入面板，只反馈结果

## 导入面板测试策略调整
导入面板候选项的自动“测试连接”不再复用完整的 Codex auto-fetch 回退链路。

原因：
1. 导入面板的目标是快速判断“此候选项是否带有可验证的 HTTP 用量查询配置”
2. 若没有显式 HTTP 配置，回退到 CLI / JSON-RPC 会把环境问题误报成账号问题
3. 用户在导入阶段更需要稳定、可解释的反馈，而不是 app-server/transport 错误

实现：
1. `testCodexImportConnectionDetached` 先解析 `CodexHTTPUsageQueryExecutor.resolveConfiguration`
2. 仅当 `resolved.source == .explicit` 时执行 HTTP usage query
3. 若 `resolved == nil` 或 `resolved.source != .explicit`，直接返回一个稳定的“跳过在线测试”错误结果

## 测试矩阵
1. OAuth 单账号导出
2. API Key 单账号导出
3. OAuth + API Key 混合导出
4. Relay 被跳过
5. 仅 relay 导出报错
6. 缺必要凭证的账号不进入结果
7. `exported_at/type/version/proxies` 顶层契约正确
8. 导入面板选中候选导出 ZIP 时，只导出当前选中的有效候选项
9. 导入面板选中候选导出 sub2api 时，relay 会被跳过并返回统计
