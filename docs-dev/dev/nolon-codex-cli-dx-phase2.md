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
