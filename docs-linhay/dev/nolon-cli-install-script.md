# nolon CLI 安装脚本（`~/.nolon/bin`）

## 目标
- 提供统一脚本将 `nolon` 可执行安装到 `~/.nolon/bin/nolon`。
- 支持 `NOLON_HOME` 隔离，便于多项目并行与测试沙盒。

## 脚本位置
- `scripts/install-nolon-cli.sh`

## 用法
```bash
# 默认安装到 ~/.nolon/bin/nolon（或 NOLON_HOME/bin/nolon）
./scripts/install-nolon-cli.sh

# 指定隔离根目录
./scripts/install-nolon-cli.sh --nolon-home /tmp/nolon-it

# 指定 debug 构建
./scripts/install-nolon-cli.sh --configuration debug

# 显式声明覆盖已有二进制（当前默认也会覆盖）
./scripts/install-nolon-cli.sh --force

# 若目标已存在则失败退出
./scripts/install-nolon-cli.sh --no-force

# 仅输出安装路径（用于脚本集成）
./scripts/install-nolon-cli.sh --print-path
```

## 参数
- `--nolon-home <path>`：安装根目录。优先级高于 `NOLON_HOME`。
- `--package-path <path>`：Swift package 路径，默认 `libs/Providers`。
- `--configuration <release|debug>`：构建配置，默认 `release`。
- `--force`：显式覆盖已存在目标（默认行为，保留作脚本自说明）。
- `--no-force`：若目标已存在则失败退出。
- `--print-path`：仅输出安装后绝对路径。

## 路径规则
- 目标根目录优先级：`--nolon-home` > `NOLON_HOME` > `~/.nolon`
- 目标二进制路径：`<root>/bin/nolon`

## 行为约束
- 默认覆盖已有目标；便于把当前源码版 CLI 直接同步到安装路径，避免“源码已更新但安装版仍是旧行为”的漂移。
- 若需要冲突保护，传 `--no-force` 时发现目标已存在会失败退出。
- 构建完成后复制产物并确保可执行权限。
- 若 `<root>/bin` 不在 `PATH`，脚本会输出 PATH 提示。

## 验证
- Smoke 测试：`scripts/tests/install-nolon-cli-smoke.sh`
- 覆盖场景：
  - 默认安装
  - `NOLON_HOME` 隔离安装
  - 默认覆盖 stale 二进制
  - `--no-force` 冲突保护
  - `--force` 显式覆盖
  - `--print-path`
  - 安装后二进制 `--help`
  - 安装后二进制 `codex --help`
  - 安装后二进制 `codex session --help`
  - 安装后二进制 `codex session list --help`
  - 安装后二进制 `codex status probe --help`
