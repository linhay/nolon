# Claude 账号配置与自定义域名支持（调研版）

## 背景
- 当前 `ProviderTemplate.claudeCode` 已内建，但仅支持 Skills / Workflows / MCP 资源管理。
- Claude 模板配置为 `supportsAccounts = false`，账号页不会展示 Claude。
- 现有架构下未提供 `~/.claude/settings.json` 的账号配置管理能力，无法在 Nolon 中维护 Claude 的 API Key / 自定义域名。
- 参考 `references/cc-switch`，Claude 常见配置为：
  - `env.ANTHROPIC_AUTH_TOKEN` 或 `env.ANTHROPIC_API_KEY`
  - `env.ANTHROPIC_BASE_URL`

## 目标
1. 支持在 Nolon 中配置 Claude 账号（至少支持 API Key / Auth Token 两种认证键位）。
2. 支持配置并校验 Claude 自定义域名（`ANTHROPIC_BASE_URL`）。
3. 支持账号切换，将选中账号写入 `~/.claude/settings.json`。
4. 在 Provider 详情中为 Claude 提供可见、可操作的账号配置入口。

## 非目标
- 本期不做 Claude 用量聚合（Usage Descriptor 仍可保持 unsupported）。
- 本期不做 Claude OAuth 自动登录流程（先支持手动录入与切换）。
- 本期不引入代理接管、故障转移与 API 格式转换能力。

## 实现进展（2026-03-11）
已完成（第一阶段）：
1. Claude 模板能力已打开：`supportsAccounts=true`、`supportsMultiAccount=true`，并增加 `vendorTabs: ["usage","rules"]`。
2. Claude 账号管理能力落地并可测试：
   - `ClaudeAccount` / `ClaudeAccountManager`
   - 手动迁移：支持从现有 `settings.json` 导入
   - cc-switch 导入：支持从 `~/.cc-switch/cc-switch.db` 导入 Claude 账号
   - 冲突处理：同冲突键下按“有效账号优先（在线探测结果）”替换
   - 激活写回：激活账号后写入 Claude `settings.json` 并更新 active snapshot
3. 用量能力接入：
   - 新增 `ClaudeUsageDescriptor`（基于 `CodexHTTPUsageQueryExecutor` 的可配置 HTTP 查询）
   - `ProviderUsageRegistry` 已将 `.claude` 从 unsupported 切换为可执行 descriptor
4. 视图映射打通：
   - `ProviderUsageViewModel.mapToUsageProvider` 增加 `claudeCode -> .claude`
   - `NolonAccountsViewModel.mapUsageProvider` 增加 `claudeCode -> .claude`

说明：
- 文档中“本期不做 Claude 用量聚合”与当前实现不一致，现已升级为“支持可配置 HTTP 用量查询（不含 Claude OAuth 自动化）”。

## 验收场景（BDD）
1. Given 已存在 Claude provider，When 进入其账号配置页，Then 可以看到当前生效账号与域名配置。
2. Given 用户新增一个 Claude 账号并填写 `ANTHROPIC_AUTH_TOKEN` 与自定义域名，When 保存，Then 账号快照可持久化且可再次编辑。
3. Given 存在多个 Claude 账号快照，When 用户激活某账号，Then `~/.claude/settings.json` 被原子更新为该账号配置。
4. Given 用户输入非法域名（非 http/https、无 host），When 保存，Then 前端阻止保存并提示错误原因。
5. Given `~/.claude/settings.json` 包含非账号字段，When 激活新账号，Then 非账号字段按“保留策略”不被破坏（具体策略由技术方案定义）。
6. Given 激活失败（权限/写入异常），When 操作结束，Then 界面展示错误并保持原激活状态不变。

## 约束
- 必须保留 `ProviderKind` 与现有 Provider 路径模型，不通过“新增多个 Claude provider”实现多账号。
- 账号数据应保存在 `~/.nolon` 体系内，避免污染业务资源目录。
- 更新 `~/.claude/settings.json` 必须采用可回滚写入策略（临时文件 + replace）。
