# Nolon Core CLI 命令面规格（M3）

- 状态：Draft
- 更新时间：2026-02-12
- 关联里程碑：`docs-dev/features/nolon-core-cli-milestones.md`（M3）

## 目标

提供稳定、可脚本消费的 `nolon-core` CLI 命令面，覆盖仓库识别/拉取、资源发现、技能标准解析。

## 命令范围

1. `skills repo plan`
- 输入：`--source`、`--repositories-root`、`--pull-strategy`(可选)、`--credential-strategy`(可选)、`--access-token`(可选)
- 输出：标准化后的 Git URL、subpath、本地 clone 路径 + `preflight`（同步策略预检结果）

2. `skills repo preflight`
- 输入：`--source`、`--pull-strategy`(可选)、`--credential-strategy`(可选)、`--access-token`(可选)
- 输出：同步策略预检结果（是否有效 URL、是否需要 token、预计凭据模式、warnings、issues）
  - `issues` 为结构化列表：`code` / `severity` / `message`（code/severity 已在 CLI 侧类型化）
  - 当前 `code`：
    - `invalid_git_url`
    - `access_token_required`
    - `token_strategy_requires_https`
    - `ssh_strategy_requires_ssh`

3. `skills repo sync`
- 输入：`--source`、`--repositories-root`、`--access-token`(可选)
- 输入（新增）：`--pull-strategy`(可选: `ff-only|rebase`)、`--credential-strategy`(可选: `automatic|token-only|ssh-only`)
- 输出：`plan` + `sync result` + `resources`（`skillsDirectories/workflows/mcps`）
- `sync result` 补充：`defaultBranch`、`credentialMode`
- 失败错误码（stderr `error.code`）：
  - `invalid_git_url`
  - `access_token_required`
  - `ssh_not_available`
  - `git_clone_failed`
  - `git_pull_failed`
  - `git_command_failed`
- 失败错误详情（stderr `error.detail`）：
  - typed 结构（JSON snake_case）：
    - `git_url: string`
    - `pull_strategy: string`
    - `credential_strategy: string`
    - `has_access_token: bool`
  - 阶段字段：`phase`（`clone|pull|command`）
  - SSH 场景字段：`host`

4. `skills discover`
- 输入：`--path`、`--max-depth`(可选)
- 输出：技能目录候选列表

5. `skills install`
- 输入：`--skill-path`、`--provider-path`、`--install-method`(可选: `symlink|copy`)、`--skill-id`(可选)
- 输出：安装结果（`skill_id/source_path/target_path/install_method`）

6. `skills uninstall`
- 输入：`--skill-id`、`--provider-path`
- 输出：卸载结果（`skill_id/target_path/removed`）

7. `skills parse`
- 输入：`--file`、`--directory-name`(可选)
- 输出：`SkillSpecificationParser` 标准元数据与 warnings

8. `resources discover`
- 输入：`--path`、`--max-depth`(可选)
- 输出：仓库资源清单（`skillsDirectories` / `workflows` / `mcps`）

9. `resources install`
- 输入：`--kind`(`workflow|mcp`)、`--file-path`、`--target-path`、`--install-method`(可选: `symlink|copy`)、`--resource-name`(可选)
- 输出：安装结果（`kind/resource_name/source_path/target_path/install_method`）

10. `resources uninstall`
- 输入：`--kind`(`workflow|mcp`)、`--resource-name`、`--target-path`
- 输出：卸载结果（`kind/resource_name/target_path/removed`）

11. `skills migrate scan`
- 输入：`--provider-path`、`--global-skills-path`
- 输出：迁移扫描结果（`states[]`，含 `skill_id/path/state`）

12. `skills migrate apply`
- 输入：`--skill-id`、`--provider-path`、`--global-skills-path`、`--install-method`(可选: `symlink|copy`)
- 输出：迁移应用结果（复用安装结果结构）

13. `remote list`
- 输入：`--kind`(`skill|workflow|mcp`)、`--query`(可选)、`--limit`(可选)、`--base-url`(可选，默认 `https://clawdhub.com`)
- 输出：远程目录列表（统一 item 结构）

14. `remote download`
- 输入：`--kind`(`skill|workflow|mcp`)、`--slug`、`--version`(可选)、`--base-url`(可选)
- 输出：下载结果（本地临时文件路径 `file_path`）

## 输出协议

1. 成功输出 JSON（stdout）
```json
{
  "ok": true,
  "command": "skills.repo.plan",
  "data": { ... }
}
```

2. 失败输出 JSON（stderr）
```json
{
  "ok": false,
  "error": {
    "code": "invalid_arguments",
    "message": "..."
  }
}
```

3. 退出码
- 成功：`0`
- 失败：`2`

## BDD 场景

### 场景 1：shorthand 仓库识别
- Given: `--source vercel/agent-skills/skills/react-best-practices`
- When: `skills repo plan`
- Then: 输出 `https://github.com/vercel/agent-skills.git`
- And: `subpath=skills/react-best-practices`
- And: 同步返回 `preflight`（例如 `credentialMode` / `requiresAccessToken`）

### 场景 2：仓库同步并发现资源
- Given: 可访问仓库源
- When: `skills repo sync`
- Then: 输出 `mode=cloned|pulled`
- And: 输出发现到的 skills 目录候选

### 场景 2.5：同步预检
- Given: `skills repo preflight --credential-strategy token-only` 且未提供 token
- When: 执行命令
- Then: 返回 `requiresAccessToken=true`
- And: `warnings` 包含 token 缺失提示
- And: `issues` 包含 `access_token_required`（`severity=error`）

### 场景 6：token-only 策略无 token
- Given: `skills repo sync --credential-strategy token-only` 且未提供 `--access-token`
- When: 执行命令
- Then: 返回 `access_token_required`，错误语义为 `access token required`

### 场景 7：默认分支输出
- Given: 本地仓库存在可识别分支（`origin/HEAD` 或当前分支）
- When: 执行 `skills repo sync`
- Then: `result.defaultBranch` 输出分支名（如 `main`）

### 场景 3：技能标准解析
- Given: `SKILL.md` 含标准 frontmatter
- When: `skills parse`
- Then: 返回 name/description/metadata/allowed-tools

### 场景 3.5：安装技能到 provider 路径
- Given: 本地技能目录与 provider 目录存在
- When: `skills install --install-method symlink|copy`
- Then: 返回结构化安装结果（含 `target_path` 与 `install_method`）

### 场景 3.6：卸载 provider 路径技能
- Given: provider 下存在对应技能目录/链接
- When: `skills uninstall`
- Then: 返回 `removed=true`，目标路径被删除

### 场景 3.7：迁移扫描
- Given: provider 目录存在技能项，global skills 目录存在同名技能
- When: `skills migrate scan`
- Then: 返回 `state`（如 `orphaned/installed/broken`）

### 场景 3.8：迁移修复
- Given: global skills 中存在目标 skill，provider 目录需修复
- When: `skills migrate apply`
- Then: 按 install-method 完成重建并返回安装结果

### 场景 4：参数缺失
- Given: 缺失 `--source`
- When: `skills repo plan`
- Then: 输出 `invalid_arguments` 错误 JSON，退出码 2

### 场景 5：资源发现
- Given: 仓库包含 `skills/*/SKILL.md`、`workflows/*.md`、`mcp_settings.json`
- When: `resources discover`
- Then: 返回结构化资源清单

### 场景 5.5：安装资源文件
- Given: 本地 workflow/mcp 文件存在
- When: `resources install --kind workflow|mcp`
- Then: 返回结构化安装结果，目标路径存在

### 场景 5.6：卸载资源文件
- Given: provider 对应路径存在资源文件
- When: `resources uninstall --kind workflow|mcp`
- Then: 返回 `removed=true` 且目标路径被删除

### 场景 6：远程目录检索
- Given: Clawdhub 可访问
- When: `remote list --kind skill --query react`
- Then: 返回统一远程 item 列表（含 slug/display_name/latest_version）

### 场景 7：远程资源下载
- Given: 远程资源 slug 存在
- When: `remote download --kind workflow --slug daily-review`
- Then: 返回本地临时文件路径 `file_path`

## 验收标准

1. 命令面在 macOS + Linux 路径语义一致。
2. 同一输入下，CLI 输出与 SDK（`SkillsRepositoryFacade`）语义一致。
3. 覆盖命令解析与执行路径的单测。
4. App 可只依赖 SDK/CLI 结果，不再复制 Git/解析细节。
