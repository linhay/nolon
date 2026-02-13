# CLI 远程仓库搜索/拉取/安装能力规格

## 背景
- app 侧已有远程仓库能力（Clawdhub/Git 仓库）用于搜索、下载与安装 skills/workflows/mcp。
- 目标是将该能力稳定下沉到 `libs/Providers`，让 `nolon` CLI 直接可用，app 仅保留编排与展示。

## 命令范围
- `nolon remote list --kind <skill|workflow|mcp> [--query <text>] [--limit <n>] [--base-url <url>]`
- `nolon remote download --kind <skill|workflow|mcp> --slug <slug> [--version <ver>] [--base-url <url>]`
- `nolon remote sync --source <git/ref> --repositories-root <path> [--access-token <token>] [--pull-strategy ...] [--credential-strategy ...] [--max-depth <n>]`
- `nolon remote sync-install --kind <skill|workflow|mcp> --source <git/ref> --repositories-root <path> (--path <repo-relative-or-absolute-path> | --slug <resource-slug>) ...`
- `nolon remote install --kind <skill|workflow|mcp> --slug <slug> [--version <ver>] [--base-url <url>] ...`
- `nolon skills repo plan|preflight|sync ...`
- `nolon skills install|uninstall|migrate|discover|parse ...`
- `nolon resources discover|install|uninstall ...`

## 路由规则
- `codex` 与顶层 `provider` 命令继续走 Codex 命令路由。
- `skills/resources/remote` 根命令统一由 `NolonCoreCLIRunner` 处理。

## 验收标准（BDD）
1. Given 用户执行 `nolon remote list`，When 参数完整，Then CLI 返回 `remote.list` 成功 envelope。
2. Given 用户执行 `nolon skills repo plan`，When 参数完整，Then CLI 返回 `skills.repo.plan` 成功 envelope。
3. Given 用户执行 `nolon remote list` 且缺少 `--kind`，Then 返回 `invalid_arguments` 且 message 明确缺少参数。
4. Given 用户执行任何 `nolon codex ...` 命令，Then 行为与当前实现保持一致（不回归）。
5. Given 用户执行 `nolon remote install --kind skill ...`，Then 返回 `remote.install` 且完成下载+安装一体化流程。
6. Given 用户执行 `nolon remote sync ...`，Then 返回 `remote.sync` 且包含 `plan/result/resources`。
7. Given 用户执行 `nolon remote sync-install ...`，Then 返回 `remote.sync-install` 且包含 `plan/result/resources/install`。

## `remote install` 参数规则
- `--kind skill`：
  - 必填：`--provider-path` 或 `--provider-id`
  - 可选：`--skill-id`（默认使用 `slug`）
  - 可选：`--install-method symlink|copy`（默认 `symlink`）
- `--kind workflow|mcp`：
  - 必填：`--target-path` 或 `--provider-id`
  - 可选：`--resource-name`
  - 可选：`--install-method symlink|copy`（默认 `symlink`）

## `--provider-id` 解析规则
- skill：
  - `provider-id -> ProviderTemplate.defaultSkillsPath`
- workflow：
  - `provider-id -> ProviderTemplate.defaultCommandPath ?? defaultWorkflowPath`
- mcp：
  - `provider-id -> dirname(ProviderTemplate.defaultMcpConfigPath)`
- 兼容别名：
  - `codex-xcode`、`codexxcode` 均映射到 `codexXcode`

## `remote sync-install` 选择规则
- 选择器要求：
  - 必须提供且仅提供一个：`--path` 或 `--slug`
- 严格模式：
  - `--strict-selector true` 时，`--slug` 若匹配多个候选文件会报错中止；
  - `--strict-selector false`（默认）时，按匹配优先级选择第一个候选。
  - `--strict-selector false` 且出现多候选时，成功返回中会附带 `install.warnings`，用于提示“已自动选择首项”。
- `--path`：
  - 支持仓库相对路径和绝对路径
- `--slug`：
  - skill：从 `skillsDirectories.skillNames` 匹配，回落到 `skills/<slug>`
  - skill 多目录命中时：
    - `--strict-selector true`：报错并返回候选列表；
    - `--strict-selector false`：选择首个并在 `install.warnings` 回传提示。
  - workflow/mcp：优先匹配完整相对路径，其次匹配文件名，再匹配去扩展名

## 非目标
- 本阶段不新增新的命令命名体系（例如 `nolon repo ...`）。
- 本阶段不引入 TUI 交互，保持 JSON 输出优先与脚本友好。
