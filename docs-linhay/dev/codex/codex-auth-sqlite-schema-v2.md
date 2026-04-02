# Codex 账号 SQLite 设计（v2）

## 1. 参考项目结论（CLIProxyAPI）

### 1.1 Codex 运行时实际读取字段
参考代码：
- `internal/runtime/executor/codex_executor.go`
- `sdk/cliproxy/auth/types.go`
- `internal/api/handlers/management/auth_files.go`

Codex 执行链路主要读取：
1. `auth.Attributes["api_key"]`（优先）
2. `auth.Attributes["base_url"]`（可选，默认 `https://chatgpt.com/backend-api/codex`）
3. 若 `api_key` 为空：回退读取 `auth.Metadata["access_token"]`
4. 刷新时读取并回写：
- `auth.Metadata["refresh_token"]`
- `auth.Metadata["id_token"]`
- `auth.Metadata["access_token"]`
- `auth.Metadata["account_id"]`
- `auth.Metadata["email"]`
- `auth.Metadata["expired"]`
- `auth.Metadata["last_refresh"]`

### 1.2 Codex Auth JSON 标准（参考项目）
参考代码：
- `internal/auth/codex/token.go` (`CodexTokenStorage`)
- `internal/misc/credentials.go` (`MergeMetadata`)

Codex 文件保存结构是“顶层扁平 JSON”（结构体字段 + 注入 metadata 合并）：

```json
{
  "id_token": "...",
  "access_token": "...",
  "refresh_token": "...",
  "account_id": "...",
  "last_refresh": "2026-04-01T00:00:00Z",
  "email": "user@example.com",
  "type": "codex",
  "expired": "2026-04-01T01:00:00Z",
  "...metadata": "..."
}
```

说明：参考项目允许 metadata 任意扩展，因此管理端会兼容读取 `priority/note` 等自定义字段。

## 2. 我们的设计目标

1. 删除 `relative_auth_path`（数据库不再保存文件路径语义）
2. 删除 `auth_json`（不再整包存 JSON）
3. 保留“可拼装 Auth JSON”的能力
4. 把自定义字段从 JSON 内嵌迁移为独立字段/表

## 3. 建议表结构

### 3.1 `codex_accounts`（账号主表）

```sql
CREATE TABLE codex_accounts (
  id TEXT PRIMARY KEY,                    -- UUID
  provider TEXT NOT NULL DEFAULT 'codex',
  display_name TEXT NOT NULL,
  account_email TEXT,
  account_id TEXT,                        -- chatgpt/openai account id
  account_kind TEXT,                      -- chatgptAccount/officialAPIKey/relayProfile
  auth_mode TEXT,                         -- chatgptAuthTokens/apikey
  status TEXT NOT NULL DEFAULT 'active',  -- active/disabled/unavailable

  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_login_at TEXT,
  last_refresh_at TEXT,
  expires_at TEXT,

  last_sync_succeeded_at TEXT,
  last_sync_failed_at TEXT,
  last_sync_failure_message TEXT
);
CREATE INDEX idx_codex_accounts_email ON codex_accounts(account_email);
CREATE INDEX idx_codex_accounts_account_id ON codex_accounts(account_id);
```

### 3.2 `codex_account_credentials`（统一凭证表：OAuth + API Key）

```sql
CREATE TABLE codex_account_credentials (
  account_id TEXT PRIMARY KEY REFERENCES codex_accounts(id) ON DELETE CASCADE,
  -- OAuth 字段
  id_token TEXT,
  access_token TEXT,
  refresh_token TEXT,
  provider_type TEXT NOT NULL DEFAULT 'codex', -- 对齐参考项目 type 字段
  -- API Key 字段
  api_key TEXT,
  base_url TEXT
);
```

### 3.3 `codex_account_usage_cache`（额度缓存）

```sql
CREATE TABLE codex_account_usage_cache (
  account_id TEXT PRIMARY KEY REFERENCES codex_accounts(id) ON DELETE CASCADE,
  cached_at TEXT,
  window_name TEXT,
  reset_at TEXT,
  remaining REAL,
  total REAL,
  raw_json TEXT
);
```

### 3.4 `codex_account_custom_fields`（可扩展自定义字段）

```sql
CREATE TABLE codex_account_custom_fields (
  account_id TEXT NOT NULL REFERENCES codex_accounts(id) ON DELETE CASCADE,
  field_key TEXT NOT NULL,
  field_value TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (account_id, field_key)
);
```

用途：`priority`、`note`、未来扩展字段统一落这里，不再污染标准凭证域。

### 3.5 `codex_active_accounts`（保持现有激活映射）

```sql
CREATE TABLE codex_active_accounts (
  provider_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES codex_accounts(id) ON DELETE CASCADE,
  updated_at TEXT NOT NULL
);
```

## 4. Auth JSON 拼装策略（运行时）

运行时从上述表拼装最小可用 JSON（仅在写 provider `auth.json`、导出、兼容 API 时使用）：

最小字段：
1. `type`（固定 `codex`）
2. `auth_mode`
3. `email`
4. OAuth 路径：`id_token/access_token/refresh_token/account_id/expired/last_refresh`
5. API Key 路径：`OPENAI_API_KEY`（可兼容附带 `base_url`）
6. 自定义字段：按需从 `codex_account_custom_fields` 合并

## 5. 迁移方案（从现状到 v2）

1. 新建 v2 表（上面 5 张）
2. 从旧 `codex_accounts(auth_json, relative_auth_path,...)` 逐行解析并拆分写入 v2 表
3. 从旧 JSON 中抽取：
- 账号域：`email/account_id/auth_mode/nolon.account.kind/...`（其中 relayProfile 将归一化为 unsupported/disabled）
- 凭证域：`tokens.id_token/tokens.access_token/tokens.refresh_token`（兼容 top-level）+ `OPENAI_API_KEY/base_url`
- Relay 域：`nolon.relay.*`（迁移时直接丢弃，不入库）
- 缓存域：`nolon.usage_cache`
- 自定义域：`priority/note/...`
4. 校验通过后切换读路径到 v2
5. 删除旧列/旧表（不再保留 `relative_auth_path/auth_json`）
6. 删除 `auth/*.json`（保留 provider 当前 `auth.json` 作为运行态文件）

## 6. 这样拆分的收益

1. 符合你提出的“去 `relative_auth_path` / 去 `auth_json`”
2. 与 CLIProxyAPI 实际读取字段对齐（`api_key/base_url` + `metadata tokens`）
3. 自定义字段彻底解耦到独立表
4. 后续增加新字段不会再触碰核心凭证结构
