# Nolon CLI/SDK Facade 指南

## 边界原则

1. `libs/Providers`：承载核心能力（可被 CLI 与 App 共同调用）
2. `nolon` App：只做编排（状态、调用顺序、UI 展示）
3. 避免双份逻辑：标准解析、Git 识别/拉取/发现仅在库层维护

## 当前统一入口

- `ProviderCatalog.SkillsRepositoryFacade`
  - `planGitImport(source:repositoriesRoot:)`
  - `syncGitRepository(...)`
  - `discoverSkillsDirectories(at:maxDepth:)`
  - `discoverRepositoryResources(at:maxDepth:)`
  - `listRemoteResources(kind:query:limit:baseURL:)`
  - `parseSkillMetadata(content:directoryName:)`
  - `normalizeGitURL(_:)`
  - `extractSubpath(from:)`
  - `extractURLComponents(from:)`
  - `parseRepositoryIdentity(from:)`
  - `detectGitProvider(from:)`
  - `suggestedClonePath(gitURL:repositoriesRoot:)`
  - `syncGitRepository(..., options:)`
    - `GitSyncOptions.pullStrategy`: `ff-only|rebase|merge`
    - `GitSyncOptions.credentialStrategy`: `automatic|prefer-ssh|token-only|ssh-only`
  - `sync` 结果补充：
    - `defaultBranch`
    - `credentialMode`（`local|ssh|https_token|https_anonymous`）
  - `preflightSync(source:accessToken:options:)`
    - 输出结构化 `issues`（`code/severity/message`）与兼容 `warnings`
    - CLI 侧 `issues` 字段使用强类型：
      - `NolonGitSyncPreflightIssueCode`
      - `NolonGitSyncPreflightIssueSeverity`
    - 预检错误码：
      - `invalid_git_url`
      - `access_token_required`
      - `token_strategy_requires_https`
      - `ssh_strategy_requires_ssh`
  - 错误边界：对外抛 `SkillsRepositoryFacade.SyncError`，不向 app 暴露 `RemoteGitRepositorySupport.SyncError`
    - 新增：`accessTokenRequired`
  - CLI 错误码映射（`NolonLiveSkillsRepositoryService`）：
    - `invalidURL` -> `invalid_git_url`
    - `accessTokenRequired` -> `access_token_required`
    - `sshNotAvailable` -> `ssh_not_available`
    - `cloneFailed` -> `git_clone_failed`
    - `pullFailed` -> `git_pull_failed`
    - `commandFailed` -> `git_command_failed`
  - CLI 错误详情映射：
    - 所有 sync 失败均带 `error.detail: NolonGitSyncErrorDetail`
    - 固定字段：`git_url/pull_strategy/credential_strategy/has_access_token`
    - `sshNotAvailable` 额外包含 `host`
    - `cloneFailed/pullFailed/commandFailed` 额外包含 `phase`
  - 类型边界：对外暴露 façade 自有类型
    - `GitSyncMode`（`cloned` / `updated`）
    - `SkillsDirectoryCandidate`
    - `ResourceFile`
    - `RepositoryResources`
  - 语义约定：底层 `pull` 在 façade 统一语义为 `updated`，CLI 层仍可映射为 `"pulled"` 做兼容输出

- `NolonCoreCLIKit` / `nolon-core`（CLI 命令面）
  - `skills repo plan`（输出 `plan + preflight`）
  - `skills repo preflight`
  - `skills repo sync`（返回同步结果 + 资源清单）
  - 策略参数已在 CLI 层类型化：
    - `pullStrategy`: `ff-only | rebase`
    - `credentialStrategy`: `automatic | token-only | ssh-only`
  - 安装命令（provider 本地目录）：
    - `skills install`（`symlink|copy`）
    - `skills uninstall`
    - `skills migrate scan/apply`（迁移助手核心扫描与修复）
    - `resources install`（`--kind workflow|mcp`，`symlink|copy`）
    - `resources uninstall`（`--kind workflow|mcp`）
  - 远程目录/下载命令：
    - `remote list`（`--kind skill|workflow|mcp`，支持 query/limit/base-url）
    - `remote download`（`--kind skill|workflow|mcp`，返回本地临时文件路径）
  - `skills discover`
  - `skills parse`
  - `resources discover`

## 典型调用流

1. 输入仓库源（`owner/repo` / HTTPS / SSH）
2. 调用 `planGitImport` 生成标准计划
3. 调用 `syncGitRepository` 执行 clone/pull
4. 调用 `discoverSkillsDirectories` 获取候选目录
5. 对具体 `SKILL.md` 调用 `parseSkillMetadata`
6. 如需跨类型资源扫描，调用 `discoverRepositoryResources`

## 资源发现约定（当前实现）

1. Skills 目录发现：
   - 支持 `skills/*/SKILL.md`、`skills/<group>/*/SKILL.md`
   - 支持隐藏目录布局：`.agents/skills/*/SKILL.md`
2. Workflow 资源发现：
   - 支持 `workflow.md`
   - 支持 `*workflow*/**/*.{md,markdown,yml,yaml}`
   - 支持 GitHub Actions：`.github/workflows/*.{yml,yaml}`
3. MCP 资源发现：
   - 支持 `mcp_settings.json` / `mcp.json`
   - 支持文件名包含 `mcp` 的 json 文件

## 迁移建议

1. App 侧凡是 `RemoteGitRepositorySupport.*` 直接调用，逐步替换为 `SkillsRepositoryFacade.*`
2. 任何 `SKILL.md` 规范解析，不再在 App 层新增规则
3. CLI 化时直接复用 façade，保持 App/CLI 一致行为
4. URL 规范化/组件提取/本地 clone 路径建议统一通过 façade，避免 app 侧绑定底层实现细节
5. 仓库显示标识（`repoName` / `owner@repo` / provider 判定）统一通过 façade 的 identity 能力，App 不再维护并行解析规则
6. 远程目录列表（skills/workflows/mcps）统一走 façade `listRemoteResources`，避免 UI 层直接依赖 `ClawdhubRepository`
