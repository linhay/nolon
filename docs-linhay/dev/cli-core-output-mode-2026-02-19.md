# CLI Core 输出模式对齐（2026-02-19）

## 目标
- 提升 `nolon skills` 核心命令可读性。
- 保持脚本自动化兼容（`--json`）。

## 本次变更
1. Core 命令输出模式
- 路由到 Core Runner 的命令（`skills/workflow/mcp/remote`）默认使用文本输出。
- 当携带 `--json` 时，切换为结构化 JSON 输出。

2. `skills repo list`
- 默认文本表格输出（repo + 统计列）。
- 新增 `--verbose`：展示 `path` 列。
- 保留 `--json` 输出结构，字段不变。

3. `skills search`
- 默认文本表格输出（slug/name/version/updated）。
- 保留 `--json` 输出结构，兼容机器调用。

4. 参数校验
- `skills search --limit` 约束为 `1...200`。
- `skills repo list --max-depth` 必须 `> 0`。

## 示例
```bash
nolon skills repo list
nolon skills repo list --verbose
nolon skills repo list --json

nolon skills search --query agent --limit 20
nolon skills search agent --limit 20
nolon skills search --query agent --json
```

## 兼容性
- 未启用文本格式的 Core 子命令，保持现有 JSON 行为（默认输出内容不变）。
- Codex 业务命令（`nolon codex ...`）行为不受影响。
