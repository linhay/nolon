# Nolon CLI ArgumentParser 解析改造

## 背景
当前 `skills/workflow/mcp/remote` 相关命令使用自定义解析器集中解析参数。为了与 swift-argument-parser 的最佳实践保持一致，需要把参数声明下沉到各个子命令类型，使用 `ParsableCommand` 与 `ArgumentParser` 进行解析。

## 目标
- 用 `ArgumentParser` 的命令树组织 `skills/workflow/mcp/remote` 的子命令，并与 `codex/provider` 合并为统一 root。
- 每个子命令声明自己的参数与校验逻辑。
- 统一帮助输出与错误文案格式（使用 ArgumentParser 生成的信息），保持执行逻辑/输出一致。

## 验收标准（BDD）

### 场景 1：技能仓库命令解析
**Given** 用户执行 `nolon skills repo plan --source vercel/agent-skills --repositories-root /tmp/repos`
**When** CLI 解析命令
**Then** 生成 `skills.repo.plan` 指令并携带对应参数

### 场景 2：workflow/mcp 命令解析
**Given** 用户执行 `nolon workflow install --file-path /tmp/source/review.md --target-path /tmp/provider/workflows`
**When** CLI 解析命令
**Then** 生成 workflow install 指令
**And** 不需要 `--kind` 参数

### 场景 3：remote install 校验
**Given** 用户执行 `nolon remote install --kind skill --slug react-best-practices`
**When** CLI 解析命令
**Then** 返回参数校验错误，提示缺少 `--provider-path` 或 `--provider-id`

### 场景 4：remote sync-install 选择器互斥
**Given** 用户同时传入 `--path` 与 `--slug`
**When** CLI 解析命令
**Then** 返回参数校验错误，提示只能选择一个选择器

### 场景 5：统一帮助输出
**Given** 用户执行 `nolon codex --help`
**When** CLI 输出帮助
**Then** 输出来自 ArgumentParser 的帮助格式（包含 `USAGE:` 与 `SUBCOMMANDS`）
**And** 帮助中包含 `codex` 的子命令列表
