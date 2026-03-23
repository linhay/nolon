# Nolon CLI Workflow/MCP 命令拆分

## 背景
现有 `nolon resources` 将 workflow 与 mcp 资源混合在同一命令组下。为提升易用性，需要拆分为两个独立顶级命令：`nolon workflow` 与 `nolon mcp`。

## 范围
- 移除 `nolon resources` 顶级命令入口（不保留兼容）。
- 新增 `nolon workflow` 与 `nolon mcp` 顶级命令，保持 discover/install/uninstall 动作。
- 命令帮助文本与路由输出需同步更新。

## 验收标准（BDD）

### 场景 1：顶级帮助显示 workflow/mcp
**Given** 用户执行 `nolon --help`
**When** CLI 输出顶级帮助
**Then** 帮助中包含 `workflow` 与 `mcp`
**And** 不再包含 `resources`

### 场景 2：workflow 命令解析
**Given** 用户执行 `nolon workflow install --file-path <path> --target-path <path>`
**When** CLI 解析命令
**Then** 生成 workflow 对应的 install 指令
**And** 不要求 `--kind` 参数

### 场景 3：mcp 命令解析
**Given** 用户执行 `nolon mcp uninstall --resource-name <name> --target-path <path>`
**When** CLI 解析命令
**Then** 生成 mcp 对应的 uninstall 指令
**And** 不要求 `--kind` 参数

### 场景 4：workflow discover 仅返回 workflow 资源
**Given** 仓库同时包含 workflow 与 mcp 文件
**When** 用户执行 `nolon workflow discover --path <repo>`
**Then** 返回的 resources 仅包含 workflow 列表
**And** mcp 列表为空

### 场景 5：mcp discover 仅返回 mcp 资源
**Given** 仓库同时包含 workflow 与 mcp 文件
**When** 用户执行 `nolon mcp discover --path <repo>`
**Then** 返回的 resources 仅包含 mcp 列表
**And** workflow 列表为空
