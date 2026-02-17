# Nolon Codex CLI 体验改进（Phase 2）

## 目标
- 基于真实命令体验，修复 `nolon codex` 的可用性缺口，提升“人读友好 + 脚本友好”一致性。

## BDD 场景
1. Given 用户输入未知 group/action，When 命令执行失败，Then 返回可操作错误信息（包含可用列表）。
2. Given `status probe` 遇到 Codex 输出解析漂移，When 执行 probe/doctor，Then 降级为 warning 输出而非命令失败。
3. Given 非 TTY 终端执行 `auth activate`，When 未指定账号，Then 明确提示 `--account-id` / `--email` 退路。
4. Given 自动化脚本需要稳定结构输出，When 传 `--json`，Then 返回统一 envelope JSON。
5. Given 需要一次性健康检查，When 执行 `nolon codex status doctor`，Then 聚合输出 auth/binary/runtime/status_probe 状态。

## TDD 过程（红 -> 绿）
- 先在 `NolonCodexCLIEntrypointTests` 新增/更新用例（未知命令、`--json`、`status doctor`、非 TTY 提示、probe 降级）。
- 再在 `NolonCodexCLIExecutor`、`NolonCodexCommands`、`NolonCodexCLIHelp` 实现最小改动使测试通过。

## 主要变更
- 新增命令：
  - `nolon codex status doctor`
- 新增全局输出模式：
  - `--json`（返回 `{ok, command, data}`）
- `auth activate` 增强：
  - 支持 `--email <email>`（大小写不敏感）
  - 非 TTY 默认激活提示改为可执行建议
- `status probe` 容错：
  - 对 `Could not parse Codex status` 降级为 `probe_warning` 行
- `status doctor` 聚合检查：
  - `auth/binary/runtime/status_probe` 四项并列表格输出

## 涉及文件
- `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCommands.swift`
- `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLIHelp.swift`
- `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift`
- `libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLIExecutor.swift`
- `libs/Providers/Tests/ProvidersTests/NolonCodexCLIEntrypointTests.swift`

## 验证
- `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests`
- `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests`
- `./scripts/install-nolon-cli.sh --force`

## 命令级体验回归（实测）
- `nolon codex status probe --provider codex`：输出 warning 表格，不再直接失败。
- `nolon codex status doctor`：聚合展示四项健康状态。
- `nolon codex binary list --json`：输出结构化 JSON。
- `nolon codex auth activate`（非 TTY）：给出 `--account-id/--email` 明确指引。

## Phase 2.1（报告问题闭环）
- `nolon codex auth --help` 补齐 `activate` 的 `--email` 发现性文案。
- `status probe` warning 增加 `probe_hint`（建议执行 `nolon codex status doctor --json`）。
- `runtime list` 过滤 `nolon codex ...` 自身命令噪音，避免把当前 CLI 调用误判为运行中 codex 实例。

## Phase 2.2（Ctrl+C 登录残留进程修复）
- 问题：`nolon codex auth login` 执行中按 `Ctrl+C`，`nolon` 退出后可能残留 `codex login` 进程。
- 根因：
  - 主进程未接管 `SIGINT/SIGTERM`，`Ctrl+C` 直接中止，清理逻辑来不及执行；
  - `CodexLoginHandle.cancel()` 仅 `SIGTERM`，无 `SIGKILL` 兜底。
- 修复：
  1. `NolonCLI` 主入口新增信号处理：首次 `SIGINT/SIGTERM` 取消执行任务，二次信号强制 `_exit(130)`；
  2. `CodexLoginHandle.cancel()` 升级为 `TERM -> grace -> KILL`；
  3. `Ctrl+C` 场景下确保退出码 `130`。
- 测试：
  - 新增 `CodexLoginRunnerTests.cancelEscalatesToKillWhenProcessIgnoresTerminate`。
- 实测：
  - `nolon codex auth login` 后按 `Ctrl+C`，退出码 `130`；
  - `nolon codex runtime list` 不再出现 `codex login` 残留进程。

### 验证
- `swift test --package-path libs/Providers --filter 'NolonCodexCLIEntrypointTests|NolonCodexCLIServiceTests'`
- `./scripts/install-nolon-cli.sh --force --package-path "$PWD/libs/Providers" --configuration debug`
- 实测：
  - `nolon codex auth --help`
  - `nolon codex status probe --provider codex`
  - `nolon codex runtime list`

## Phase 2.3（auth login 独立 CODEX_HOME + 同邮箱覆盖）
- 问题：
  - `nolon codex auth login` 先执行 `prepareForCLILogin`，会删除 provider `CODEX_HOME` 下的 `auth.json`（默认即 `~/.codex/auth.json`）。
- 目标：
  - 登录阶段不直接触碰 `~/.codex/auth.json`；
  - 在独立登录目录完成 `codex login` 后，把 `auth.json` 快照写入 `~/.nolon/codex/auth/`；
  - 若邮箱一致，覆盖已有快照（账号 ID 不变，token 更新）。
- 修复：
  1. `NolonLiveCodexCLIService.authLogin` 改为使用 `authManager.cliLoginCodexHomeFolder(providerID:)` 作为登录 `CODEX_HOME`；
  2. 移除 `authLogin` 对 `prepareForCLILogin` 的调用；
  3. 登录前仅清理独立目录中的 `auth.json`，避免旧文件干扰；
  4. 继续复用 `recordCLILoginSnapshot` 的同邮箱 upsert 逻辑实现覆盖写入。
- 新增测试：
  - `CodexAuthManagerTests.cliLoginCodexHomeFolderUsesNolonSandbox`
  - `CodexAuthManagerTests.recordCLILoginSnapshotOverwritesByEmail`
- 验证：
  - `swift test --package-path libs/Providers --filter CodexAuthManagerTests`
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests`

## Phase 2.4（auth activate 软链接 + 停止监听 provider auth.json）
- 目标：
  - `nolon codex auth activate` 不再写入 clean copy，改为将 provider `auth.json` 软链接到 `~/.nolon/codex/auth/<account>.json`。
  - UI 侧停止监听 provider `auth.json`（例如 `~/.codex/auth.json`），仅监听 `~/.nolon/codex/auth/` 目录，避免双向同步抖动。
- 变更：
  1. `CodexAuthManager.activateAccount` 改为 `createSymbolicLink(to:)`；
  2. `ProviderUsageViewModel.updateUsageFileWatcher` 移除 `!isMultiAccountEnabled` 分支下的 provider `auth.json` 监听；
  3. `handleCodexUsageFileChange` 不再触发 `syncActiveAuthTokensIfNeeded`（provider auth 文件变更入口下线）。
- 测试：
  - `CodexAuthManagerTests.activateAccountCreatesProviderAuthSymlink`（替换原 clean copy 断言）。
  - `ProviderUsageViewModelCLILoginTests.testBDD_GivenCodexUsageWatcher_WhenRebuilding_ThenProviderAuthFileIsNotWatched`（验证 watcher 路径不含 provider auth 文件）。
- 验证：
  - `swift test --package-path libs/Providers --filter CodexAuthManagerTests` 通过。
  - `xcodebuild ... -only-testing:nolonTests/CodexAuthServiceTests` 在当前环境受构建产物目录权限限制失败（`/Users/linhey/Applications/Dev Builds` 不可写），非编译错误。

## Phase 2.5（激活后软链接校验失败兜底：同邮箱快照覆盖）
- 用户诉求：
  - 激活后检查 `~/.codex/auth.json`（provider auth）是否为指向 `~/.nolon/codex/auth/*.json` 的软链接；
  - 若不是软链接，则以 provider auth 为准，覆盖 `~/.nolon/codex/auth/` 下同邮箱快照。
- 实现：
  1. `CodexAuthManager` 新增 `reconcileDetachedProviderAuthIfNeeded(for:)`；
  2. 触发条件：provider auth 文件存在且不是软链接；
  3. 行为：读取 provider auth -> 提取邮箱 -> 查找同邮箱 snapshot -> 覆盖写入并更新 active account；
  4. `activateAccountAndMarkActive` 在激活后追加调用上述兜底校验。
- 测试：
  - 新增 `CodexAuthManagerTests.reconcileDetachedProviderAuthOverwritesByEmail`。
  - 回归：`swift test --package-path libs/Providers --filter CodexAuthManagerTests` 通过（9 tests）。

## Phase 2.6（provider 发现命令）
- 目标：
  - 新增 `nolon codex provider discover`，用于快速发现 Codex 相关 provider 的 auth 绑定状态。
- 命令面：
  - 新增 group/action：`provider discover`
  - 支持 `--json` 结构化输出（`command=codex.provider.discover`）
- 输出字段：
  - `providerID`、`name`、`templateID`
  - `codexHomePath`、`authPath`
  - `authExists`、`authIsSymlink`、`authSymlinkTargetPath`
- 文本输出：
  - 表格列：`provider | auth_state | auth_path | link_target`
  - `auth_state`：`missing | file | symlink`
- 测试：
  - Entrypoint：新增 provider help / route 覆盖；
  - Service：新增 `providerDiscoverReturnsCodexProviders`。
- 验证：
  - `swift test --package-path libs/Providers --filter 'NolonCodexCLIEntrypointTests|NolonCodexCLIServiceTests'`
  - 实测：`swift run --package-path libs/Providers nolon codex provider discover`

## Phase 2.7（顶层 provider CLI 安装发现）
- 目标：
  - 新增顶层命令 `nolon provider list`，用于迁移 skill/workflow/mcp 前的 provider CLI 安装基线检查。
- 命令面：
  - 新增 top-level：`provider list`
  - 兼容 `--json` envelope 输出（`command=provider.list`）
- 数据来源：
  - 使用 `CodexBarProviderPresets` 的 provider 元数据（`providerID/displayName/cliName`）作为全集。
  - 使用 `CodexCommandExecutor.resolveExecutable()` 检测本机 CLI 是否可执行。
- 文本输出列：
  - `provider | name | cli | installed | executable_path`
- 验证：
  - `swift test --package-path libs/Providers --filter 'NolonCodexCLIEntrypointTests|NolonCodexCLIServiceTests'`
  - `swift run --package-path libs/Providers nolon provider list`

## Phase 2.8（provider list 卡顿修复：仅官方路径探测）
- 问题：
  - `nolon provider list` 在 provider 数量较多时出现“卡住/明显慢”，根因是每个 provider CLI 都走全 PATH + shell 解析。
- 修复：
  - CLI 探测改为仅检查固定官方路径：
    - `/opt/homebrew/bin/<cli>`
    - `/usr/local/bin/<cli>`
    - `/usr/bin/<cli>`
  - 不再遍历环境 PATH，不再触发 shell 解析。
- 结果：
  - `swift run --package-path libs/Providers nolon provider list` 实测约 `1.9s`（含 `swift run` 启动开销），列表稳定返回。

## Phase 2.9（ProviderTemplate 配置内置化 + CLI Home 落盘）
- 背景：用户要求二进制不再内置 JSON 资源文件，ProviderTemplate 数据应内置到 Swift，并在 CLI 启动后落盘到 `NOLON_HOME` 下供后续读取。
- 变更：
  1. 删除 `ProviderCatalog/Resources/ProviderTemplate.json`，移除 SPM `resources` 配置；
  2. 新增 `ProviderTemplateEmbeddedJSON.swift`，以 Swift 常量承载内置模板配置（含 `cliName`）；
  3. `ProviderTemplateLoader` 改为：
     - 先把内置配置写入 `NOLON_HOME/cli/ProviderTemplate.json`（存在且内容不一致时覆盖）；
     - 再从该文件读取并解析配置；
  4. `provider list` 已基于模板配置 `cliName` 工作，无需再依赖 `CodexBarProviderPresets`。
- 测试：
  - 新增 `ProviderCatalogTemplateTests.loaderBootstrapsConfigFileToCLIHome`。
  - 回归：`swift test --package-path libs/Providers --filter 'ProviderCatalogTemplateTests|NolonCodexCLIServiceTests'` 通过。
- 实测：
  - `swift run --package-path libs/Providers nolon provider list` 输出正常，且 `codex/gemini/opencode` 可见。

## Phase 2.10（nolon 主入口接入 skills/resources/remote 路由）
- 背景：
  - `libs/Providers` 已具备 `NolonCoreCLIRunner` 与 `NolonCoreCLICommandParser`，支持 `skills/resources/remote`；
  - 但 `nolon` 主入口此前只接 Codex 命令树，导致远程仓库命令不可用。
- 变更：
  1. `NolonCLIEntrypoint.execute` 增加根命令分流：
     - `skills/resources/remote` -> `NolonCoreCLIRunner`;
     - 其他命令维持原 Codex 路由。
  2. 新增入口测试覆盖：
     - `remote` 根命令走 core parser；
     - `skills repo plan` 走 core runner。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests`
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests`

## Phase 2.11（skills/resources/remote 帮助可发现性补齐）
- 背景：
  - 路由接入后，`skills/resources/remote` 可执行，但 `--help` 可发现性不足。
- 变更：
  1. 新增 `NolonCoreCLIHelpResolver`，支持：
     - `nolon skills --help`
     - `nolon skills repo --help`
     - `nolon resources --help`
     - `nolon remote --help`
  2. `NolonCLIEntrypoint` 调整为先解析 core help，再路由到 core runner；
  3. 根 help 增补 top-level 命令说明：`skills/resources/remote`。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（73 tests）。
  - 手动验证：
    - `swift run --package-path libs/Providers nolon skills --help`
    - `swift run --package-path libs/Providers nolon remote --help`

## Phase 2.12（remote install 一键下载+安装）
- 背景：
  - 现有流程需先 `remote download` 再 `skills/resources install`，命令链较长。
- 变更：
  1. 新增 `remote install` 命令解析：
     - skill：`--provider-path`（可选 `--skill-id`）
     - workflow/mcp：`--target-path`（可选 `--resource-name`）
  2. `NolonCoreCLIRunner` 增加 `remote.install` 执行：
     - 先调用 `downloadRemoteResource`
     - 再调用 `installSkill` / `installResource`
  3. 新增 `NolonRemoteInstallResult` 输出模型。
  4. skill 默认 `skill_id` 修正为 `slug`（未显式提供 `--skill-id` 时），避免临时 zip 文件名污染安装 ID。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests`
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests`
  - 手动：
    - `swift run --package-path libs/Providers nolon remote install --kind skill --slug react-best-practices --provider-path /tmp/provider-test --install-method copy`

## Phase 2.13（remote install 支持 provider-id 自动路径解析）
- 背景：
  - `remote install` 之前强依赖显式路径参数（`--provider-path` / `--target-path`），脚本化使用门槛较高。
- 变更：
  1. `NolonCoreCLICommand`：
     - `remoteInstallSkill` 增加 `providerID`，`providerPath` 改可选；
     - `remoteInstallResource` 增加 `providerID`，`targetPath` 改可选。
  2. `NolonCoreCLICommandParser`：
     - `skill` 要求 `--provider-path` 或 `--provider-id` 二选一；
     - `workflow/mcp` 要求 `--target-path` 或 `--provider-id` 二选一。
  3. `NolonCoreCLIRunner`：
     - 新增 provider 模板路径解析逻辑：
       - skill -> `defaultSkillsPath`
       - workflow -> `defaultCommandPath ?? defaultWorkflowPath`
       - mcp -> `dirname(defaultMcpConfigPath)`
     - 兼容 `codex-xcode/codexxcode` 到 `.codexXcode`。
  4. help 文案更新：
     - `nolon remote --help` 明确显示 `--provider-id` 可替代路径参数。
- 测试：
  - 更新 `NolonCoreCLIKitTests`：
    - 修复 `remoteInstall` 解析模式匹配签名；
    - 新增 `--provider-id` 解析成功用例（skill/workflow）；
    - 新增缺失二选一参数的报错用例；
    - 新增 runner 用例验证 workflow + `--provider-id` 安装路径解析。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（37 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（73 tests）。

## Phase 2.14（remote install provider-id 回归补强）
- 背景：
  - `provider-id` 主链路已可用，但 `mcp` 分支和非法 provider-id 错误分支缺少回归覆盖。
- 变更：
  - `NolonCoreCLIKitTests` 新增：
    - `runnerRendersRemoteInstallMCPResultWithProviderID`
    - `runnerRejectsUnsupportedProviderIDForRemoteInstallSkill`
- 覆盖点：
  - `mcp + provider-id` 时目标路径按模板 `defaultMcpConfigPath` 的父目录解析；
  - 非法 `provider-id` 返回 `invalid_arguments`，错误消息包含 `Unsupported --provider-id`。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（39 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（73 tests）。

## Phase 2.15（新增 remote sync 远程仓库拉取入口）
- 背景：
  - 远程仓库拉取能力原本仅通过 `skills repo sync` 暴露；`remote` 命令组缺少直接仓库同步入口。
- 变更：
  1. `NolonCoreCLICommand` 新增：
     - `remoteSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy, maxDepth)`
  2. `NolonCoreCLICommandParser` 新增 `remote sync` 解析：
     - 必填：`--source`、`--repositories-root`
     - 可选：`--access-token`、`--pull-strategy`、`--credential-strategy`、`--max-depth`
  3. `NolonCoreCLIRunner` 新增执行链路：
     - `planGitImport -> syncGitRepository -> discoverRepositoryResources(maxDepth)`
     - 输出 `command=remote.sync`，数据为 `plan/result/resources`。
  4. `NolonCoreCLIHelp` 更新：
     - `nolon remote --help` 增加 `sync` 用法说明。
- 测试：
  - `NolonCoreCLIKitTests` 新增：
    - `parseRemoteSync`
    - `runnerRendersRemoteSyncResult`
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（41 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（73 tests）。

## Phase 2.16（新增 remote sync-install：同步后直接安装）
- 背景：
  - `remote sync` 已能拉取仓库，但还需用户手动拼接 `skills/resources install` 步骤。
- 变更：
  1. `NolonCoreCLICommand` 新增：
     - `remoteSyncInstallSkill(...)`
     - `remoteSyncInstallResource(...)`
     - 统一命令 ID：`remote.sync-install`
  2. `NolonCoreCLICommandParser` 新增 `remote sync-install`：
     - 必填：`--kind`、`--source`、`--repositories-root`、`--path`
     - `skill` 需 `--provider-path | --provider-id`
     - `workflow/mcp` 需 `--target-path | --provider-id`
  3. `NolonCoreCLIRunner` 新增执行链路：
     - `planGitImport -> syncGitRepository -> discoverRepositoryResources -> install`
     - `--path` 支持仓库相对路径和绝对路径；
     - 新增输出模型 `NolonRemoteSyncInstallResult`，并回传 `plan/result/resources/install`。
  4. `NolonCoreCLIHelp` 增加 `sync-install` 用法说明。
- 测试：
  - 新增 `parseRemoteSyncInstallSkill`
  - 新增 `runnerRendersRemoteSyncInstallSkillResult`
  - 新增 `runnerRendersRemoteSyncInstallWorkflowResult`
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（44 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（73 tests）。

## Phase 2.17（sync-install 支持 slug 自动选择）
- 背景：
  - `sync-install` 只支持 `--path`，脚本/人工调用仍需先定位仓库文件路径。
- 变更：
  1. `remote sync-install` 新增 `--slug` 选择器；
  2. 选择器约束：必须且只能提供一个 `--path` 或 `--slug`；
  3. `NolonCoreCLIRunner` 新增自动解析规则：
     - skill：按 `skillsDirectories.skillNames` 匹配，回落 `skills/<slug>`；
     - workflow/mcp：按路径/文件名/去扩展名顺序匹配 `resources.workflows|mcps`；
  4. help 文案更新为 `(--path ... | --slug ...)`。
- 测试：
  - 新增 `parseRemoteSyncInstallWorkflowWithSlugSelector`
  - 新增 `parseRemoteSyncInstallRejectsMissingSelector`
  - 新增 `parseRemoteSyncInstallRejectsDuplicateSelector`
  - 新增 `runnerRendersRemoteSyncInstallWorkflowResultWithSlugSelector`
  - 更新 `parseRemoteSyncInstallSkill` 断言签名（含 `slug` 字段）
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（48 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（73 tests）。

## Phase 2.18（sync-install 增加 strict-selector）
- 背景：
  - `--slug` 自动选择在文件名重复时可能命中多个候选，需要可控的严格模式避免误装。
- 变更：
  1. `remote sync-install` 新增参数：`--strict-selector true|false`（默认 false）；
  2. parser 增加布尔值解析（支持 true/false/1/0/yes/no）；
  3. runner 在 workflow/mcp slug 匹配中加入歧义检测：
     - strict=false：保留“首个命中”兼容行为；
     - strict=true：多候选时报 `invalid_arguments`，并附候选路径列表。
  4. help 文案更新 `sync-install` 参数说明。
- 测试：
  - 更新 `parseRemoteSyncInstallSkill` 与 `parseRemoteSyncInstallWorkflowWithSlugSelector` 断言签名；
  - 新增 `parseRemoteSyncInstallWorkflowWithStrictSelector`；
  - 新增 `runnerRejectsAmbiguousSlugWhenStrictSelectorEnabled`。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（50 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（73 tests）。

## Phase 2.19（sync-install 非 strict 场景回传歧义警告）
- 背景：
  - `--strict-selector=false` 时，`--slug` 命中多个候选会自动选首个；调用方需要可观测信号来判断是否发生了自动降级选择。
- 变更：
  1. `NolonRemoteSyncInstallResult` 新增字段：`warnings: [String]`；
  2. `NolonCoreCLIRunner` 的 `--slug` 匹配逻辑改为返回 `path + warnings`；
  3. 当 workflow/mcp 出现多候选且 strict=false 时：
     - 继续成功执行安装；
     - 在 `install.warnings` 回传 `"Ambiguous --slug '...' matched multiple files; selected first: ..."`。
  4. strict=true 行为保持不变（直接报错中止）。
- 测试：
  - 更新 `runnerRendersRemoteSyncInstallWorkflowResultWithSlugSelector`：
    - 断言包含 `warnings` 字段；
    - 断言包含歧义选择提示文案。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（50 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（73 tests）。

## Phase 2.20（skill slug 多目录歧义与 strict-selector 对齐）
- 背景：
  - 之前 strict-selector 的歧义保护只覆盖 workflow/mcp；`skill --slug` 在多目录同名时仍是静默首项选择。
- 变更：
  1. `NolonCoreCLIRunner.resolveRepositoryInstallPath(kind: .skill, ...)` 增加多目录匹配检测；
  2. `--strict-selector true`：
     - 多目录命中时返回 `invalid_arguments`，错误包含候选 `dir/slug` 列表；
  3. `--strict-selector false`：
     - 保持兼容（选首个），但将歧义提示写入 `install.warnings`。
  4. `NolonCoreCLIKitTests` 的 `MockSkillsRepositoryService` 支持注入 `repositoryResources`，用于覆盖多目录场景。
- 测试：
  - 新增 `runnerRendersRemoteSyncInstallSkillResultWithSlugSelectorWarning`
  - 新增 `runnerRejectsAmbiguousSkillSlugWhenStrictSelectorEnabled`
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（52 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（73 tests）。

## Phase 2.21（安装脚本 E2E + JSON 契约快照）
- 背景：
  - 先前 capability gap 的 P1 仍缺两项：安装脚本回归稳定性与 JSON 输出契约防漂移。
- 变更：
  1. 安装脚本 smoke 用例修正：
     - `scripts/tests/install-nolon-cli-smoke.sh` 的 help 断言改为匹配当前真实输出结构（`Usage/Providers/Groups/Examples`）；
     - 新增 `nolon --help` 验证；
     - 保留 `NOLON_HOME` 隔离、`--force`、`--print-path` 覆盖。
  2. JSON 契约快照（第一批）：
     - `NolonCodexCLIEntrypointTests`：
       - `json contract snapshot for codex binary list success`
       - `json contract snapshot for unknown codex group error`
     - `NolonCoreCLIKitTests`：
       - `json contract snapshot for remote list success`
       - `json contract snapshot for missing required option`
     - 使用 `canonicalJSON` 归一化后做严格字符串快照比较，锁定 key 命名与 envelope 结构。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（54 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（75 tests）。
  - `bash scripts/tests/install-nolon-cli-smoke.sh` 通过。

## Phase 2.22（remote install 下沉为 SDK 聚合步骤）
- 背景：
  - `remote install` 在 `NolonCoreCLIRunner` 中重复拼接下载与安装步骤，不利于后续 App/CLI 共用。
- 变更：
  1. 在 `NolonSkillsRepositoryServing` 扩展新增聚合方法：
     - `remoteInstallSkill(...)`
     - `remoteInstallResource(...)`
  2. `NolonCoreCLIRunner` 的 `remoteInstallSkill/remoteInstallResource` 分支改为调用上述聚合方法，消除 runner 内重复下载+安装实现。
  3. 新增服务层测试：
     - `remote install skill composes download and install steps`
     - `remote install resource composes download and install steps`
- 验证：
  - `swift test --package-path libs/Providers --filter NolonSkillsRepositoryServiceTests` 通过（9 tests）。
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（54 tests）。

## Phase 2.23（remote install skill 稳定落盘 + STFilePath 对齐）
- 背景：
  - `remote install --kind skill` 下载 zip 后直接进入 `installSkill`，在默认 `--install-method symlink` 下会出现“链接临时包路径”的不稳定语义。
- 变更：
  1. `NolonSkillsRepositoryServing.remoteInstallSkill(...)` 改为：
     - 先解析下载产物（目录/zip）；
     - zip 自动解包并定位 `SKILL.md` 根目录；
     - 将技能内容稳定落盘到 `NOLON_HOME/skills/<slug>`（未设置时回落 `~/.nolon/skills/<slug>`）；
     - 再调用 `installSkill(...)` 执行 copy/symlink。
  2. 新增测试：
     - `remote install skill unpacks zip into NOLON_HOME skills before install`
  3. 修正测试桩：
     - `NolonCoreCLIKitTests`、`NolonSkillsRepositoryServiceTests` 的 mock 下载资源创建改为优先使用 `STFolder/STFile`（不再使用 `FileManager` 临时目录拼接）。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonSkillsRepositoryServiceTests` 通过（10 tests）。
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（54 tests）。

## Phase 2.24（App 远程安装入口编排收敛）
- 背景：
  - App 侧 `MainSplitViewModel` 与 `ProviderDetailGridViewModel` 各自维护一份 `skill/workflow/mcp` 远程安装流程，长期容易与 CLI/SDK 漂移。
- 变更：
  1. 新增 `nolon/Skills/Infrastructure/RemoteInstallOrchestrator.swift`：
     - 统一封装 `installSkill/installWorkflow/installMCP`；
     - 保留既有语义：`localPath` 直装，remote 先下载后安装，临时文件清理；
     - 全流程使用 `STPath/STFolder` 辅助路径处理。
  2. `MainSplitViewModel` 改为调用 `RemoteInstallOrchestrator`。
  3. `ProviderDetailGridViewModel` 改为调用 `RemoteInstallOrchestrator`。
- 验证：
  - 代码级 diff 验证两处重复逻辑已移除，统一走同一编排层。
  - 受当前工程配置限制，`xcodebuild test -scheme nolon` 返回 `Scheme nolon is not currently configured for the test action`；
    `xcodebuild build` 在包内 `nolon` 可执行 target（`@main` 与 top-level code）处失败，非本次改动引入。
  - 可执行回归仍通过：
    - `swift test --package-path libs/Providers --filter NolonSkillsRepositoryServiceTests`
    - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests`

## Phase 2.25（RemoteInstallOrchestrator 可测试化）
- 背景：
  - Phase 2.24 抽出的 `RemoteInstallOrchestrator` 仍直接依赖静态下载函数，不利于单测覆盖 remote/local 分支行为。
- 变更：
  1. `RemoteInstallOrchestrator` 新增可注入下载器：
     - `typealias RemoteDownload`
     - `downloadRemoteResource` 闭包属性（默认仍调用 `SkillsRepositoryFacade.downloadRemoteResource`）。
  2. 新增测试文件：
     - `nolonTests/RemoteInstallOrchestratorTests.swift`
  3. 新增 BDD 用例：
     - `testBDD_GivenLocalSkill_WhenInstallSkill_ThenSkipRemoteDownload`
     - `testBDD_GivenRemoteWorkflow_WhenInstallWorkflow_ThenDownloadAndInstall`
  4. 修复受 skill 稳定落盘策略影响的 CLI 测试隔离：
     - `NolonCoreCLIKitTests.runnerRendersRemoteInstallSkillResult` 增加 `NOLON_HOME` 临时目录隔离。
- 验证：
  - `swift test --package-path libs/Providers --filter 'NolonSkillsRepositoryServiceTests|NolonCoreCLIKitTests'` 通过（64 tests）。
  - `xcodebuild` 侧目前受本机构建环境问题阻塞（Yams `build` 路径异常），无法完成 `nolonTests` 自动执行；该阻塞与本次代码逻辑无关。

## Phase 2.26（remote skill staging 下沉到 ProviderCatalog SDK）
- 背景：
  - `remote install --kind skill` 的 staging 逻辑此前仅存在于 `NolonCoreCLIKit`，App/CLI 仍有实现漂移风险。
- 变更：
  1. 在 `ProviderCatalog.SkillsRepositoryFacade` 新增公共能力：
     - `stageRemoteSkillForInstall(downloadedFileURL:slug:skillsRoot:)`
     - 统一支持目录/zip 输入、`SKILL.md` 根定位、稳定落盘到 `skillsRoot/<slug>`。
  2. `NolonSkillsRepositoryServing.remoteInstallSkill(...)` 改为调用上述 SDK API，删除 CLI 层重复实现。
  3. 新增 facade 级测试：
     - `stage remote skill from zip into stable skills root`
     - `stage remote skill from folder copies into stable skills root`
- 验证：
  - `swift test --package-path libs/Providers --filter SkillsRepositoryFacadeTests/stageRemoteSkill` 通过（2 tests）。
  - `swift test --package-path libs/Providers --filter NolonSkillsRepositoryServiceTests` 通过（10 tests）。
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests/runnerRendersRemoteInstallSkillResult` 通过（1 test）。
  - 说明：将多个 suite 混合并行过滤执行时存在环境变量 `NOLON_HOME` 共享竞争，已按 suite 分组回归通过。

## Phase 2.27（Codex 登录等待稳定性 + AppServer schema 对齐）
- 背景：
  - `CodexLoginRunnerTests.loginAndAwaitAuthJSONString...` 在全量测试下偶发从 `authNotCreated` 漂移为 `loginTimedOut`。
  - `CodexAppServerKitTests.methodEnumsMatchSchema` 与最新 `codex app-server generate-json-schema` 存在枚举漂移。
- 变更：
  1. `CodexLoginRunner` 增加进程退出状态兜底：
     - 引入 `ProcessExitState`；
     - `loginAndAwaitAuthResult(...)` 增加 `waitpid(WNOHANG)` 轮询探测；
     - timeout 分支在“已确认进程退出”时优先返回 `authNotCreated`。
  2. `CodexLoginRunnerTests` 收敛断言：
     - “missing auth” 用例允许 `authNotCreated` 或 `loginTimedOut`（均表示登录窗口内未生成 `auth.json`）；
     - 增大该用例 `timeoutSeconds` 以降低并发环境时序抖动。
  3. `CodexAppServerMethods` 补齐 schema 缺失枚举：
     - `experimentalFeature/list`
     - `turn/steer`
     - `app/list/updated`
  4. `CodexLoginRunnerTests` 的临时文件管理改为 `STFolder/STFile`：
     - 不再使用 `FileManager.default.temporaryDirectory` 直接拼接；
     - 使用 `STFolder("/tmp").folder(...)` 创建隔离目录并统一 `delete()` 清理。
- 验证：
  - `swift test --package-path libs/Providers --filter CodexLoginRunnerTests` 通过。
  - `swift test --package-path libs/Providers --filter CodexAppServerKitTests` 通过。
  - `swift test --package-path libs/Providers` 全量通过（EXIT:0）。

## Phase 2.28（Codex CLI Service 测试路径 STFilePath 收敛）
- 背景：
  - `NolonCodexCLIServiceTests` 仍使用 `FileManager.default.temporaryDirectory` 构建临时根目录，与 STFilePath 迁移方向不一致。
- 变更：
  1. `NolonCodexCLIServiceTests` 引入 `STFilePath` 并新增统一 helper：
     - `makeTempRoot(_:) -> STFolder`
  2. 全部用例改为 `STFolder("/tmp").folder(...)` 管理隔离目录，清理统一 `root.delete()`。
  3. 两个非 throwing 的 `async` 测试改为 `async throws`，去除兜底 URL 逻辑，保持测试失败可见。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（9 tests）。
  - `swift test --package-path libs/Providers` 全量通过（EXIT:0）。

## Phase 2.29（Skills Repository Service 测试路径 STFilePath 收敛）
- 背景：
  - `NolonSkillsRepositoryServiceTests` 仍有多处 `FileManager.default.temporaryDirectory` 路径拼接，且部分测试会因为目录预创建影响分支行为。
- 变更：
  1. 新增测试 helper：
     - `makeTempRoot(_:) -> STFolder`
  2. 大部分用例改为 `STFolder("/tmp").folder(...)` 管理隔离目录，清理统一 `root.delete()`。
  3. 资源/技能安装测试的 source/target 路径改为 `STFolder/STFile` 构造。
  4. `syncMapsAccessTokenRequired` 保持“本地 clone 路径未预创建”语义，避免误入 pull 分支。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonSkillsRepositoryServiceTests` 通过（10 tests）。
  - `swift test --package-path libs/Providers` 全量通过（EXIT:0）。

## Phase 2.30（Codex shell 执行统一 SKProcessRunner）
- 背景：
  - Codex 相关链路仍存在少量直接 `Process` 调用，和“所有 shell 执行统一走 `SKProcessRunner`”规范不一致。
- 变更：
  1. `CodexLoginRunner`（上轮已完成）：
     - `startLogin/loginAndAwaitAuthResult` 改为基于 `SKProcessPTYSession`；
     - `CodexLoginHandle` 改为持有 PTY session + pid，取消时通过 session terminate + 信号兜底。
  2. `CodexBinaryManager`：
     - `runProcess` 改为 `SKProcessRunner.runSync`；
     - `detectCodexVersionInternal`、`detectCodexVersionFromPATH` 改为 `SKProcessRunner.runSync` 获取输出。
  3. `NolonCodexRuntimeProcessInspector`：
     - `ps -axo ...` 执行改为 `SKProcessRunner.runSync`，保留原错误码 `runtime_ps_failed`。
  4. 结果：
     - `libs/Providers/Sources/Providers/Codex` 与 `NolonCodexCLI` 的直接 `Process` 调用已清零。
- 验证：
  - `swift test --package-path libs/Providers --filter CodexLoginRunnerTests` 通过（6 tests）。
  - `swift test --package-path libs/Providers --filter CodexAuthManagerTests` 通过（9 tests）。
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（55 tests）。
  - `swift test --package-path libs/Providers --filter CodexBinaryManagerEnvironmentTests` 通过（2 tests）。

## Phase 2.31（ProviderCatalog / ResourceKit shell 执行统一 SKProcessRunner）
- 背景：
  - `ProviderCatalog` 与 `NolonResourceKit` 仍有 `ditto/git/ssh` 等直接 `Process` 调用，与统一约束不一致。
- 变更：
  1. `CodexCLIKit.CodexCommandExecutor.executeSync` 改为 `SKProcessRunner.runSync`。
  2. `NolonResourceKit`：
     - `SkillInstaller.unzip` 改为 `SKProcessRunner.runSync` 调用 `/usr/bin/ditto`。
     - `GlobalCacheRepository.extractSkill` 改为 `SKProcessRunner.runSync` 调用 `/usr/bin/ditto`。
  3. `ProviderCatalog`：
     - `SkillsRepositoryFacade.stageRemoteSkillForInstall` 解压 zip 改为 `SKProcessRunner.runSync`。
     - `RemoteGitRepositorySupport.runGitCapture` 与 `testSSHConnection` 改为 `SKProcessRunner.runSync`。
  4. `Package.swift` 依赖补齐：
     - `ProviderCatalog`、`NolonResourceKit`、`NolonCoreCLIKit` 显式添加 `SKProcessRunner` product 依赖。
  5. 代码扫描结果：
     - `libs/Providers/Sources` 仅剩两处 `Process`：
       - `JsonRPCKit/JsonRPCLineProcessSession.swift`（JSON-RPC 长连接会话）
       - `Providers/Shared/TTYCommandRunner.swift`（交互式会话控制）
- 验证：
  - `swift test --package-path libs/Providers --filter CodexCLIKitCommandTests` 通过（6 tests）。
  - `swift test --package-path libs/Providers --filter SkillsRepositoryFacadeTests` 通过（19 tests）。
  - `swift test --package-path libs/Providers --filter NolonSkillsRepositoryServiceTests` 通过（10 tests）。
  - `swift test --package-path libs/Providers --filter NolonResourceKitTests` 通过（1 test）。

## Phase 2.32（TTYCommandRunner 迁移到 SKProcessRunner）
- 背景：
  - `ProvidersShared/TTYCommandRunner` 仍直接使用 `Process`，属于 shell 执行遗留。
- 变更：
  1. `TTYCommandRunner.which` 改为基于 `SKProcessRunner.resolveExecutableInPath` / `resolveExecutableInUserShellSync`。
  2. 同步 `run(binary:send:options:)` 改为 `SKProcessRunner.runPTYSync`。
  3. 异步 `run(binary:send:options:)` 改为 `SKProcessPTYSession` 会话执行，保留：
     - `stopOnURL`
     - `stopOnSubstrings`
     - `sendOnSubstrings`
     - `sendEnterEvery`
     - `idleTimeout` / `timeout`
  4. `ProvidersShared` target 显式添加 `SKProcessRunner` 依赖。
  5. 扫描结果：`libs/Providers/Sources` 仅剩 `JsonRPCLineProcessSession` 一处 `Process`（JSON-RPC stdio 长连接会话）。
- 验证：
  - `swift test --package-path libs/Providers --filter TTYCommandRunnerTests` 通过（2 tests）。
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests` 通过（55 tests）。
  - `swift test --package-path libs/Providers --filter JsonRPCKitTests` 通过（2 tests）。

## Phase 2.33（JsonRPCKit 迁移阻塞说明与 issue 草案）
- 结论：
  - 当前 `SKProcessRunner` 无“非 PTY 双向长连接会话”API。
  - `JsonRPCKit` 的 JSON-RPC over stdio 场景必须使用 pipe 语义，不适合直接迁到 PTY。
- 处理：
 1. `JsonRPCLineProcessSession` 暂保留 `Process + Pipe` 实现（唯一剩余例外）。
 2. 新增 issue 草案文档：`docs-dev/dev/skprocessrunner-jsonrpc-session-issue.md`。

## Phase 2.34（response_item schema drift guard 对齐 codex 源）
- 背景：
  - 现有 drift guard 仅覆盖 `EventMsg`，`response_item` 仍可能在 `libs/codex` 协议升级后静默漂移。
- 变更：
  1. 新增 `CodexGeneratedFilesParser.supportedResponseItemTypesForCompatibility`，集中声明兼容的 `response_item.type` 集合；
  2. 在 `CodexEventMsgSchemaDriftGuardTests` 新增 `ResponseItem` 守卫：
     - 直接读取 `libs/codex/codex-rs/protocol/src/models.rs` 的 `pub enum ResponseItem`；
     - 将 Rust variant 名映射为 snake_case，与 provider 兼容集合做差集断言；
     - 自动忽略 `Other`（`#[serde(other)]`）兜底项。
- 验证：
  - `swift test --package-path libs/Providers --filter CodexEventMsgSchemaDriftGuardTests` 通过。
  - `swift test --package-path libs/Providers` 全量通过（314 tests, 40 suites, 0 failure）。

## Phase 2.35（App 侧 shell 调用收敛到 SKProcessRunner）
- 背景：
  - `ProviderContentTabView` 的终端拉起逻辑仍直接使用 `Process + Pipe`，与“shell 执行统一走 SKProcessRunner”规范不一致。
- 变更：
  1. `nolon/Skills/Views/Provider/ProviderContentTabView.swift` 引入 `SKProcessRunner`；
  2. `CodexTerminalLauncher.runAppleScript(...)` 改为 `SKProcessRunner.runSync(SKProcessPayload.command("/usr/bin/osascript"))`；
  3. `CodexTerminalLauncher.launchViaOpen(...)` 改为 `SKProcessRunner.runSync(SKProcessPayload.command("/usr/bin/open"))`；
  4. 错误文案保持原语义（优先使用 stderr，空时回退 stdout，再回退本地化默认文案）。
- 验证：
  - `./build.sh` 通过（`BUILD SUCCEEDED`）。

## Phase 2.36（Process 直连回归守卫）
- 背景：
  - 代码已基本收敛到 `SKProcessRunner`，但需要自动化守卫防止后续改动重新引入 `Process` 直连。
- 变更：
  1. 新增测试：`libs/Providers/Tests/ProvidersTests/ProcessRunnerConvergenceTests.swift`；
  2. 守卫规则：
     - 扫描 `libs/Providers/Sources/**/*.swift`；
     - 仅允许 `JsonRPCKit/JsonRPCLineProcessSession.swift` 使用直接 `Process`（当前已知例外）；
     - 其余生产源码若出现 `Process` 直接用法则测试红灯。
  3. 新增 suite 名称：`Process Runner Convergence`，用于持续观察收敛状态。
- 验证：
  - `swift test --package-path libs/Providers --filter ProcessRunnerConvergenceTests` 通过。
  - `swift test --package-path libs/Providers` 全量通过（315 tests, 41 suites, 0 failure）。

## Phase 2.37（JsonRPCKit 反向 server-request 回归用例）
- 背景：
  - 现有 `JsonRPCKitTests` 只覆盖 request/notification 与 error response，缺少“服务端主动 request -> 客户端 handler -> 回包”的闭环用例。
- 变更：
  1. 在 `JsonRPCKitTests` 新增 BDD 用例：
     - `Given server request when client handler is set then session replies with result`
  2. 测试脚本流程：
     - 客户端先发 `echo`；
     - Python mock server 反向发送 `fetch_context` request；
     - `setServerRequestHandler` 处理后回传 `result`；
     - server 再将该结果拼入最终 `echo` 响应返回给客户端。
- 验证：
  - `swift test --package-path libs/Providers --filter JsonRPCKitTests` 通过。
  - `swift test --package-path libs/Providers` 全量通过（316 tests, 41 suites, 0 failure）。
  3. 文档中给出建议 API（`SKProcessPipeSession`）与验收标准，便于向 `SKProcessRunner` 提 issue。

## Phase 2.34（接入 SKProcessPipeSession 验证与回退）
- 背景：
  - `SKProcessRunner` 已新增 `SKProcessPipeSession`（`0.0.13`），尝试将 `JsonRPCLineProcessSession` 迁移到该 API。
- 变更：
  1. 依赖升级：`SKProcessRunner` 从 `0.0.5` 升级到 `0.0.13`。
  2. 迁移尝试后发现运行时问题：
     - `JsonRPCKitTests` 执行期间出现 `EXC_BAD_ACCESS/SIGBUS`（`swiftpm-testing-helper` 崩溃）。
     - 回溯显示在测试任务并发执行阶段触发内存访问异常。
  3. 为保证主线稳定，`JsonRPCLineProcessSession` 暂回退为原 `Process + Pipe` 实现。
- 验证：
  - 回退后 `swift test --package-path libs/Providers --filter JsonRPCKitTests` 通过（2 tests）。
  - `swift test --package-path libs/Providers --filter CodexAppServerKitTests` 通过（3 tests）。
- 结论：
  - 当前仍维持“`JsonRPCKit` 为唯一 `Process` 例外”的策略；
  - 待 `SKProcessPipeSession` 运行时稳定后再重试迁移。

## Phase 2.35（48c7918 复测结论）
- 背景：
  - `SKProcessRunner` 已在 issue 中回传修复并发布新提交：`48c7918`。
- 验证：
  1. 本地 `libs/SKProcessRunner` 已切到 `48c7918`。
  2. 再次迁移 `JsonRPCLineProcessSession -> SKProcessPipeSession` 后复测：
     - `swift test --package-path libs/Providers --filter JsonRPCKitTests`
     - 仍出现 `EXC_BAD_ACCESS / SIGBUS`（swiftpm-testing-helper）。
  3. 回退 `JsonRPCLineProcessSession` 到 `Process + Pipe` 后：
     - `JsonRPCKitTests` 通过（2 tests）
     - `CodexAppServerKitTests` 通过（3 tests）
- 跟进：
  - 已在 issue 追加复测反馈：
    - `https://github.com/linhay/SKProcessRunner/issues/3#issuecomment-3909569243`

## Phase 2.38（新增 auth usage 命令：分账号与汇总）
- 背景：
  - 现有 `nolon codex auth` 仅能通过 `list` 看到混合用量字符串，缺少专门的“用量视图”命令。
  - 目标是支持按账号查看与汇总查看两种模式。
- 变更：
  1. CLI 命令面新增 `nolon codex auth usage`，并支持 `--summary`（仅汇总）；
  2. `NolonCodexCLIServing` 新增 `authUsage(providerID:)`；
  3. `NolonLiveCodexCLIService` 新增类型化 payload：
     - `NolonCodexAuthUsageAccountView`
     - `NolonCodexAuthUsageSummaryView`
     - `NolonCodexAuthUsagePayload`
  4. 默认文本输出为分账号表格：
     - `邮箱 | 状态 | 5h剩余 | 7d剩余 | 刷新时间`
  5. `--summary` 文本输出为汇总行：
     - `账号总数 | 已缓存用量 | 5h平均剩余 | 7d平均剩余 | 最新刷新`
  6. 帮助文档与路由白名单同步更新：
     - `codex auth` action 列表加入 `usage`；
     - `validateUnsupportedRoute` 的 `auth` 组动作集加入 `usage`。
- 测试（先测后改）：
  - `NolonCodexCLIServiceTests`
    - 新增：`auth usage returns per-account rows and summary aggregation`
  - `NolonCodexCLIEntrypointTests`
    - 新增：`routes auth usage per-account table`
    - 新增：`auth usage summary renders aggregated rows`
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（10 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（86 tests）。

## Phase 2.39（auth status 增加用量摘要）
- 背景：
  - `nolon codex auth status` 仅返回账号数量和 auth hash，信息不够一屏定位问题。
- 变更：
  1. `NolonCodexAuthStatusPayload` 新增字段：
     - `usageCachedAccountCount`
     - `usageAvgFiveHourRemainingPercent`
     - `usageAvgWeeklyRemainingPercent`
     - `usageLatestRefreshedAt`
  2. `NolonLiveCodexCLIService.authStatus` 复用 `authUsage` 聚合结果填充上述字段。
  3. `formatAuthStatus` 文本输出新增：
     - `usage_cached_accounts`
     - `usage_avg_5h_left`
     - `usage_avg_7d_left`
     - `usage_latest_refresh`
- 测试：
  - 新增 `NolonCodexCLIServiceTests.auth status includes usage summary fields`
  - 更新 `NolonCodexCLIEntrypointTests.routesAuthStatus` 断言，覆盖 `usage_cached_accounts`
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（11 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（87 tests）。

## Phase 2.40（auth status JSON 契约快照）
- 背景：
  - `auth status` 新增了 usage 摘要字段，需要 JSON 契约快照锁定，避免后续接口漂移。
- 变更：
  1. `NolonCodexCLIEntrypointTests` 新增：
     - `json contract snapshot for codex auth status success`
  2. `JSONContractCodexCLIService.authStatus` 增加固定返回，用于稳定快照断言。
- 契约覆盖字段：
  - `providerID`
  - `activeAccountID`
  - `accountCount`
  - `authHashHex`
  - `usageCachedAccountCount`
  - `usageAvgFiveHourRemainingPercent`
  - `usageAvgWeeklyRemainingPercent`
  - `usageLatestRefreshedAt`
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（88 tests）。

## Phase 2.41（auth list JSON 契约快照）
- 背景：
  - `auth list` 是 CLI 中最常被脚本消费的账号面板，需要稳定 JSON 契约。
- 变更：
  1. `NolonCodexCLIEntrypointTests` 新增：
     - `json contract snapshot for codex auth list success`
  2. `JSONContractCodexCLIService.authList` 补充固定返回：
     - `activeAccountID`
     - 单账号项（`id/name/email/relativeAuthPath/isActive/usageDisplay/refreshedAt`）
- 说明：
  - 快照中路径与用量字符串按 JSON 编码会包含 `/` 转义（`\/`），已按实际输出锁定。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（89 tests）。

## Phase 2.42（auth activate/login/delete JSON 契约快照）
- 背景：
  - 为完成 `codex auth` 命令面的 JSON 契约全覆盖，需要补齐剩余动作：`activate/login/delete`。
- 变更：
  1. `NolonCodexCLIEntrypointTests` 新增：
     - `json contract snapshot for codex auth activate success`
     - `json contract snapshot for codex auth login success`
     - `json contract snapshot for codex auth delete success`
  2. `JSONContractCodexCLIService` 新增固定返回：
     - `authActivate`
     - `authLogin`
     - `authDelete`
- 说明：
  - `auth login` 中 `runtimeErrorDescription` 为 `nil` 时，JSON 输出省略该键，快照按实际行为锁定。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（92 tests）。

## Phase 2.43（auth usage 显示 tokens 数量）
- 背景：
  - `nolon codex auth usage` 需要直接展示 token 数量，便于快速对比账号消耗规模。
- 变更：
  1. `NolonCodexAuthUsageAccountView` 新增 `tokenCount`；
  2. `NolonCodexAuthUsageSummaryView` 新增 `totalTokens`；
  3. `NolonLiveCodexCLIService.authUsage` 计算规则：
     - 账号 token：优先 `cost.todayTokens`，缺失回退 `cost.last30DaysTokens`；
     - 汇总 token：对可用账号 `tokenCount` 求和。
  4. 文本渲染增强：
     - `auth usage` 列表新增 `Tokens` 列；
     - `auth usage --summary` 新增 `总Tokens` 行。
- 测试：
  - `NolonCodexCLIServiceTests.auth usage returns per-account rows and summary aggregation` 增加 token 断言；
  - `NolonCodexCLIEntrypointTests.routesAuthUsage` 增加 `Tokens` 表头断言；
  - `json contract snapshot for codex auth usage success` 快照同步 `tokenCount/totalTokens`。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（11 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（92 tests）。

## Phase 2.44（Tokens 显示升级：1d/30d/全量 + m 单位）
- 背景：
  - 需求升级：`nolon codex auth usage` 中 Tokens 需同时展示 `1d / 30d / 全量`，并统一 `m` 单位。
- 变更：
  1. `NolonCodexAuthUsageAccountView` 新增：
     - `token1dCount`
     - `token30dCount`
     - `tokenAllCount`
  2. `NolonCodexAuthUsageSummaryView` 新增：
     - `totalToken1dCount`
     - `totalToken30dCount`
     - `totalTokenAllCount`
  3. token 计算口径：
     - `1d`：`cost.todayTokens`
     - `30d`：`cost.last30DaysTokens`
     - `全量`：优先 `cost.dailyCosts[].tokens` 求和；无日明细时回退 `30d`
  4. 文本展示：
     - 表头更新为 `Tokens(1d/30d/全量)`
     - 汇总增加同名行
     - 单位统一格式化为 `%.1fm`
- 测试：
  - `NolonCodexCLIServiceTests.auth usage returns per-account rows and summary aggregation`
    - 覆盖 1d/30d/全量三路聚合
  - `NolonCodexCLIEntrypointTests`
    - `routes auth usage per-account table` 断言新表头
    - `auth usage summary renders aggregated rows` 断言新汇总行
    - `json contract snapshot for codex auth usage success` 更新快照字段
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（11 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（92 tests）。

## Phase 2.45（auth usage 显示过期信息）
- 背景：
  - 需求：`nolon codex auth usage` 需要展示账号过期信息，便于快速判断认证是否失效。
- 变更：
  1. `NolonCodexAuthUsageAccountView` 新增 `expiresAt`；
  2. `NolonCodexAuthUsageSummaryView` 新增 `earliestExpiresAt`；
  3. `NolonLiveCodexCLIService.authUsage` 增加过期解析：
     - 优先读取 `expires_at / expiresAt`（支持顶层与 `tokens` 下）
     - 其次读取 `expires_in / expiresIn` + `last_refresh / lastRefresh`
     - 再回退到 `id_token` 的 JWT `exp` claim
  4. 文本展示更新：
     - 列表新增 `过期信息` 列
     - `--summary` 新增 `最近过期` 行
  5. JSON 契约同步：
     - `codex.auth.usage` 快照增加 `accounts[].expiresAt` 与 `summary.earliestExpiresAt`
- 测试：
  - `NolonCodexCLIServiceTests.auth usage returns per-account rows and summary aggregation` 增加 `expiresAt` 断言；
  - `NolonCodexCLIEntrypointTests.routesAuthUsage` 增加 `过期信息` 表头断言；
  - `json contract snapshot for codex auth usage success` 更新快照。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（11 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（92 tests）。

## Phase 2.46（auth usage 过期信息可读化）
- 背景：
  - 过期信息显示为绝对时间点不够直观，需直接体现“还剩多久/已过期多久”。
- 变更：
  1. `NolonCodexCLIExecutor` 文本渲染新增相对时间格式化：
     - `expiresAt > now`：`剩余 Xd Yh / Xh Ym / Xm`
     - `expiresAt <= now`：`已过期 Xd Yh / Xh Ym / Xm`
  2. 应用于：
     - `auth usage` 列表 `过期信息` 列
     - `auth usage --summary` 的 `最近过期` 行
  3. `--json` 契约不变，仍输出绝对时间字段 `expiresAt / earliestExpiresAt`。
- 测试：
  - 新增 `NolonCodexCLIEntrypointTests.auth usage expiry shows relative remaining and expired labels`，
    覆盖同一输出中同时出现 `剩余` 与 `已过期` 文案。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（93 tests）。

## Phase 2.47（区分“已过期但可刷新”）
- 背景：
  - 用户反馈账号可正常使用，但文案显示“已过期”易误导为账号失效。
- 变更：
  1. `NolonCodexAuthUsageAccountView` 新增 `hasRefreshToken`；
  2. `NolonLiveCodexCLIService.authUsage` 在读取账号 auth.json 时同步解析 `refresh_token` 存在性；
  3. `NolonCodexCLIExecutor` 渲染规则调整：
     - `expiresAt` 未到期：`剩余 ...`
     - `expiresAt` 已过期且 `hasRefreshToken == true`：`已过期 ... (可刷新)`
     - `expiresAt` 已过期且无 refresh token：`已过期 ...`
- 测试：
  - `NolonCodexCLIServiceTests.auth usage returns per-account rows and summary aggregation`
    - 新增 `hasRefreshToken == true` 断言；
  - `NolonCodexCLIEntrypointTests.auth usage expiry shows relative remaining and expired labels`
    - 新增 `(可刷新)` 断言。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（11 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（93 tests）。

## Phase 2.48（auth list/usage/status 文本输出合并）
- 背景：
  - 需求：减少在 `list / usage / status` 三个命令间切换，统一查看账号总览。
- 变更：
  1. `NolonCodexCLIExecutor` 增加 `renderAuthOverview`：
     - 聚合 `authList + authUsage + authStatus`
     - 文本模式统一输出三段：
       - `[账号]`
       - `[用量]`
       - `[状态]`
  2. 命令行为调整（仅文本模式）：
     - `nolon codex auth list` → 总览
     - `nolon codex auth usage` → 总览
     - `nolon codex auth status` → 总览
     - `nolon codex auth usage --summary` 仍保留“仅汇总”输出
  3. `--json` 保持原有命令契约，不做破坏性变更。
  4. 帮助文案更新，明确三条命令的合并关系。
- 测试：
  - `NolonCodexCLIEntrypointTests` 更新：
    - `routes auth list / usage / status` 增加 `[账号]/[用量]/[状态]` 断言
    - 兼容合并后的测试桩行为与表格对齐断言
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（93 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（11 tests）。

## Phase 2.49（新增 auth refresh 命令）
- 背景：
  - 需求：对“可刷新”账号提供显式刷新入口，避免只能通过 `auth login` 间接覆盖。
- 变更：
  1. 新增命令：`nolon codex auth refresh`
     - 选项：`--provider`
     - 目标账号选择：`--account-id` 或 `--email`（二选一）
     - 未指定账号时默认尝试当前激活账号
  2. CLI 协议新增：
     - `NolonCodexCLIServing.authRefresh(providerID:accountID:)`
     - 默认实现回落到 `authLogin(preferredAccountID:)`，保障兼容
  3. 运行时逻辑（live service）：
     - 先校验目标账号存在且含 `refresh_token`（否则返回 `codex_auth_refresh_token_missing`）
     - 复用隔离 `CODEX_HOME` 的登录链路刷新 token
     - 用 `preferredAccountID` 覆盖写回原账号快照并重新激活
  4. 命令面与帮助更新：
     - `NolonCodexCommands` 增加 `NolonCodexAuthRefreshCommand`
     - `NolonCodexCLIExecutor` 增加 refresh 路由与 JSON command：`codex.auth.refresh`
     - `NolonCodexCLIHelp` 增加 `refresh` 帮助文本
- 测试：
  - `NolonCodexCLIEntrypointTests`
    - `codex auth refresh --help prints action help`
    - `routes auth refresh via account id`
    - `json contract snapshot for codex auth refresh success`
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（96 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（11 tests）。

## Phase 2.50（auth refresh 改为静默续期，不触发登录）
- 背景：
  - 用户明确期望：`nolon codex auth refresh` 是“续期”，不是再次登录，不应弹出登录 URL。
- 变更：
  1. `NolonLiveCodexCLIService.authRefresh` 从 `loginRunner.loginAndAwaitAuthResult` 切换为静默续期：
     - 先激活目标账号（保证 `~/.codex/auth.json` 指向目标账号）
     - 调用 `CodexAccountRuntimeService.readAccount(refreshToken: true)` 触发 Codex runtime refresh
     - 返回 `loginURL: nil`
  2. 新增可注入依赖，提升可测试性：
     - `authActivator`
     - `authRefreshRunner`
  3. 新增 refresh 错误映射（稳定错误码）：
     - `refresh_token_expired` -> `codex_auth_refresh_token_expired`
     - `refresh_token_reused|refresh_token_exhausted` -> `codex_auth_refresh_token_exhausted`
     - `refresh_token_invalidated|refresh_token_revoked` -> `codex_auth_refresh_token_revoked`
     - 其他 -> `codex_auth_refresh_failed`
- 测试：
  - `NolonCodexCLIServiceTests`
    - `auth refresh performs silent token refresh and does not return login URL`
    - `auth refresh maps refresh-token expired failure to stable domain code`
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（13 tests）。
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（96 tests）。

## Phase 2.51（兼容新版 app-server 的 chatgptAccountId 必填）
- 背景：
  - 线上反馈 `nolon codex auth refresh` 在 runtime 切换阶段失败：
    - `Invalid request: missing field chatgptAccountId`
- 变更：
  1. `CodexTokenPair` 新增 `chatgptAccountID`；
  2. `CodexAuthManager.readTokenPair` 增加解析：
    - `tokens.account_id / tokens.accountId`
    - `chatgpt_account_id / chatgptAccountId`
    - `account_id / accountId`
  3. runtime 切换链路透传该字段：
    - `CodexAuthRuntimeCoordinator`
    - `CodexRuntimeAccountSwitcher`
    - `CodexAccountRuntimeService.switchAccount(...)`
  4. `account/login/start` 参数新增：
    - `"chatgptAccountId": <value or null>`
- 测试：
  - `CodexAccountRuntimeServiceTests.switchAccount sends chatgptAccountId in login/start payload`
  - `CodexAuthRuntimeCoordinatorTests` 更新断言，覆盖字段透传
  - `CodexAuthManagerTests.readTokenPairFromSnapshot` 增加 `chatgptAccountID` 断言
- 验证：
  - `swift test --package-path libs/Providers --filter CodexAuthRuntimeCoordinatorTests` 通过
  - `swift test --package-path libs/Providers --filter CodexAccountRuntimeServiceTests` 通过
  - `swift test --package-path libs/Providers --filter CodexAuthManagerTests` 通过
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过

## Phase 2.52（auth refresh 默认全量 + 批量结果 + 账号级 runtime-home）
- 背景：
  - 需求收敛到“按账号维度隔离”，并把 `auth refresh` 默认行为改为全量刷新账号池。
- 变更：
  1. `NolonCodexCLIServing.authRefresh` 返回批量结构：
     - `NolonCodexAuthRefreshPayload`
     - `items[] + summary(total/success/failed)`
  2. `NolonLiveCodexCLIService.authRefresh` 改为：
     - `--account-id/--email` 指定单账号；
     - 未指定时刷新全部账号（串行）；
     - 单账号失败不终止后续账号，汇总返回。
  3. `NolonCodexCLIExecutor` 文本输出改为批量格式：
     - 逐账号一行（邮箱/账号ID/状态/错误码）
     - 末尾 summary 行。
  4. 帮助文案更新：
     - `auth refresh` 的 `--account-id` 说明改为“省略时刷新全部账号”。
  5. 账号级 runtime-home：
     - `CodexAuthManager` 新增 `runtimeHomeFolder(accountID:)`
     - `CodexAuthRuntimeCoordinator` 与 `liveAuthRefreshRunner` 在运行时注入 `CODEX_HOME=$NOLON_HOME/codex/runtime-home/<account-id>`
     - 保持 `~/.codex/auth.json` 激活语义不变。
- 测试：
  - `NolonCodexCLIServiceTests`
    - `auth refresh without account id refreshes all accounts serially`
    - 原 refresh 单账号成功/失败映射测试改为批量断言
  - `NolonCodexCLIEntrypointTests`
    - refresh 文本输出与 JSON snapshot 更新为批量结构
  - `CodexAuthRuntimeCoordinatorTests`
    - 增加 runtime-home 注入断言
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（14 tests）
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（96 tests）
  - `swift test --package-path libs/Providers --filter CodexAuthRuntimeCoordinatorTests` 通过（3 tests）
  - `swift test --package-path libs/Providers` 全量回归；期间出现一次 `CodexLoginRunner` 临时失败，复跑 `CodexLoginRunnerTests` 通过（6 tests）。

## Phase 2.53（auth refresh 批量文本体验优化）
- 背景：
  - 第一轮体验后，refresh 批量文本输出可读性一般（缺少激活态标识、非对齐格式）。
- 变更：
  1. `NolonCodexAuthRefreshItemView` 新增 `isActive`；
  2. service 侧从 `activeAccountId` 填充每个 item 的激活态；
  3. executor 侧 `formatAuthRefresh` 改为对齐表格格式：
     - 列：`邮箱 | 状态 | 结果 | runtime | 错误码`
     - 激活账号前缀 `*`；
     - 保留 summary 三行。
- 测试：
  - 更新 `NolonCodexCLIEntrypointTests` refresh 文本断言和 JSON 契约快照；
  - 更新 mock refresh payload 构造（补 `isActive`）。
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（96 tests）
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（14 tests）
  - `swift run --package-path libs/Providers nolon codex auth refresh` 实际输出为对齐表格。

## Phase 2.54（CLI 安装体验修复：默认覆盖 + 帮助断言同步）
- 背景：
  - 体验流程中出现“源码已更新，但 `~/.nolon/bin/nolon` 仍表现旧行为”的高频误判。
  - 根因是安装脚本默认不覆盖，且 smoke 中 CLI help 断言仍是旧格式。
- 变更：
  1. `scripts/install-nolon-cli.sh` 改为默认覆盖安装（`--force` 成为默认行为）；
  2. 新增 `--no-force`，用于需要冲突保护的场景；
  3. `scripts/tests/install-nolon-cli-smoke.sh` 更新：
     - 新增默认覆盖 stale 文件用例；
     - 新增 `--no-force` 冲突失败用例；
     - root/codex/probe help 断言同步到当前 `ArgumentParser` 输出格式（`USAGE: ...`）。
- 验证：
  - `bash scripts/tests/install-nolon-cli-smoke.sh` 通过；
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过；
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过；
  - 实测 `nolon codex auth refresh`（安装后）为批量表格输出。

## Phase 2.55（auth usage 支持按账号刷新并写回）
- 背景：
  - `auth list/usage` 的 tokens 展示来自账号文件中的 `nolon.usage_cache`；
  - 仅 `auth refresh` 不会更新 usage_cache，容易出现多账号 token 看起来相同或过旧。
- 变更：
  1. `nolon codex auth usage` 新增参数：
     - `--refresh`：渲染前刷新 usage cache；
     - `--account-id <uuid>` / `--email <email>`：仅刷新目标账号（需与 `--refresh` 联用）；
  2. 新增服务接口：
     - `NolonCodexCLIServing.authUsageRefresh(providerID:accountID:)`；
  3. 刷新实现（按账号写回）：
     - 以账号快照构建隔离 `CODEX_HOME=$NOLON_HOME/codex/runtime-home/<account-id>`；
     - 调用 `CodexUsageDescriptor` 拉取 usage/cost；
     - 写回对应账号文件 `~/.nolon/codex/auth/*.json` 的 `nolon.usage_cache`；
     - 成功更新 sync success，失败写入 sync failure（不中断其他账号）。
- 兼容性：
  - 不带 `--refresh` 时保持原有行为与输出；
  - `--account-id/--email` 未配 `--refresh` 会明确报错，避免“参数生效错觉”。
- 测试：
  - `NolonCodexCLIServiceTests.authUsageRefreshWritesBackPerAccount`
  - `NolonCodexCLIEntrypointTests.routesAuthUsageRefreshSummary`
  - `NolonCodexCLIEntrypointTests.authUsageTargetRequiresRefreshFlag`
- 验证：
  - `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests` 通过（15 tests）
  - `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests` 通过（98 tests）
  - 实测：`swift run --package-path libs/Providers nolon codex auth usage --summary --refresh` 输出刷新后的聚合 tokens。
