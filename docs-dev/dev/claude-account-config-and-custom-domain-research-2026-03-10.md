# Claude 账号配置与自定义域名支持调研（参考 cc-switch）

## 1. 结论摘要
- **当前 Nolon 不支持 Claude 账号配置**：既没有账号数据模型，也没有 `~/.claude/settings.json` 的写入链路。
- **当前 Nolon 不支持 Claude 自定义域名配置**：没有 `ANTHROPIC_BASE_URL` 的 UI、校验与持久化能力。
- **参考 cc-switch 可落地字段非常明确**：Claude 配置核心就是 `env` 下的 API Key/Token + Base URL。
- **建议采用“单 Provider + 多账号快照”方案**：复用 Codex 的账号管理思路，不走“多个 Claude provider”方案。

## 2. 现状差距（Nolon）

### 2.1 模板与入口
- `ProviderTemplateEmbeddedJSON` 中 Claude 为：
  - `supportsAccounts: false`
  - 未配置 `vendorTabs` 的 `usage/accounts` 入口
- 结果：
  - `Tools -> Accounts` 的筛选逻辑不会包含 Claude。
  - Claude Provider 详情页没有账号配置入口。

### 2.2 数据模型
- `Provider` 结构当前只有路径/展示属性，不承载 Claude 账号配置。
- `AddProviderSheet` / `EditProviderSheet` 只有名称与路径，无法录入 Claude 凭据与域名。

### 2.3 运行时能力
- `ProviderUsageRegistry` 对 `UsageProvider.claude` 仍返回 `UnsupportedUsageDescriptor`。
- `ProviderUsageViewModel` 的账号管理逻辑基本为 Codex/Gemini 特化，Claude 无实现。
- 代码库内没有 Claude 专用配置管理器（类似 `CodexAuthManager` / `GeminiAuthStore`）。

## 3. 参考 cc-switch 关键信息

### 3.1 配置结构
`references/cc-switch/docs/user-manual/zh/2-providers/2.1-add.md` 给出的 Claude 自定义配置：

```json
{
  "env": {
    "ANTHROPIC_API_KEY": "your-api-key",
    "ANTHROPIC_BASE_URL": "https://api.example.com"
  }
}
```

cc-switch 同时支持：
- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_API_KEY`
- `ANTHROPIC_BASE_URL`

### 3.2 存储与写入策略
- `settings_config` 中以 JSON `env` 管理 Claude 配置。
- 切换时写入 Claude live 配置（`~/.claude/settings.json`）。
- 内部字段（如 `apiFormat`）在写 live 配置时会做 sanitize，避免污染 CLI 配置文件。

### 3.3 可借鉴点
- API Key 字段兼容（Token / API Key 双键位）。
- Base URL 显式管理 + 基础校验。
- 写 live 配置时只写必要字段、内部字段分离。

## 4. 建议实现方案（分阶段）

## Phase 1（最小可用）
- 新增 `ClaudeAccountManager`（建议放 `libs/Providers/Sources/ProviderUsage` 或 `NolonResourceKit`）。
- 账号快照落盘到 `~/.nolon/claude/accounts.json`（或 `~/.nolon/claude/accounts/*.json`）。
- 账号字段：
  - `id/name`
  - `credentialType`（`authToken` / `apiKey`）
  - `credentialValue`
  - `baseURL`
  - `updatedAt`
- 新增激活态索引（如 `~/.nolon/claude/active-account.json`）。
- 激活逻辑：将账号配置写入 `~/.claude/settings.json` 的 `env`。

## Phase 2（集成到 UI）
- 给 Claude provider 增加可见入口（建议 `usage` tab，避免新增并行心智模型）。
- 在 `ProviderUsageView` 为 Claude 增加“配置模式”：
  - 列表：账号快照 + 当前激活标记
  - 操作：新增 / 编辑 / 删除 / 激活
  - 表单：Token/API Key + Base URL + 校验提示

## Phase 3（兼容与保护）
- 读取现有 `~/.claude/settings.json`，自动导入/对齐为“当前账号”快照。
- 写入策略增加“保留非账号字段”能力（例如已有插件相关配置时不覆盖）。
- 增加回滚：写入失败回退到上一个可用版本。

## 5. BDD/TDD 测试计划

### 5.1 先写失败测试（Red）
1. `ClaudeAccountManagerTests`
   - 新增账号后可持久化读取。
   - Base URL 非法时保存失败。
   - 激活账号时生成正确 `env`。
2. `ClaudeLiveSettingsWriterTests`
   - 激活后写入 `~/.claude/settings.json`（使用临时目录替身）。
   - 写入失败回滚成功。
   - 保留非账号字段策略正确。
3. `ProviderTemplate/Presentation` 相关测试
   - Claude 开启账号支持后，入口可见性符合预期（仅目标页面显示）。

### 5.2 最小实现（Green）
- 仅实现通过上述测试所需最小代码路径，不引入额外行为。

### 5.3 重构（Refactor）
- 抽离公共 JSON 原子写入器与 URL 校验工具。
- 统一错误码与用户提示文案 key。

## 6. 风险与决策点
- 风险 1：Claude CLI 对 `settings.json` 字段兼容性可能因版本变化而波动。
  - 对策：只写 `env` 必要键，其他字段保守透传。
- 风险 2：若直接覆盖整个文件，可能丢失用户已有配置。
  - 对策：默认 merge 写入，严格限制覆写键集合。
- 风险 3：把多账号映射为多个 Provider 会与现有路径唯一性冲突。
  - 对策：坚持“单 Provider + 多账号快照”。

## 7. 建议落地顺序
1. 先完成 `ClaudeAccountManager` + 单元测试。
2. 再打开 Claude 的入口开关与最小 UI。
3. 最后补迁移、兼容与回滚策略。
