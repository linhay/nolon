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
