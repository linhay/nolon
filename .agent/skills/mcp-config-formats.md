# Skill: mcp-config-formats

用于在 Nolon 中实现/修复 MCP（编辑、读取、迁移、安装）相关功能时，快速对齐“不同 Provider 的 MCP 配置文件路径与 JSON 结构”，避免凭经验猜测造成返工。

## scope
- 本仓库（Nolon）
- 任务类型：MCP（UI/解析/安装/迁移/缓存）

## do
- **先确认官方文档**：如果用户提供 provider 官方链接，优先以官方为准，明确：
  - 配置文件路径（绝对/相对、是否位于 `~/.config/...` 等）
  - 顶层 key（如 `mcp` / `mcpServers` / `mcp_servers`）
  - server schema（`type/url/command/args/env/headers/enabled` 等字段）
- **再确认代码映射点（最小闭环）**：
  - ProviderTemplate 配置：`libs/Providers/.../ProviderTemplate.json` 的 `vendorHomeRelativePath` + `defaultMcpConfigPath`
  - 计数入口：`nolon/Skills/Views/Provider/ProviderContentTabViewModel.loadCounts`
  - 列表入口：`nolon/Skills/Views/Provider/ProviderDetailGridViewModel.loadMCPs`
  - 写入入口：启用/禁用、删除、安装（ResourceInstaller）
  - 创建空配置：`ProviderMcpGridView` “Create Configuration”
- **迁移策略**：`~/.nolon/mcps` 采用“一 MCP 一文件”，默认逐个迁移：
  - 未迁移：显示“迁移”
  - 已迁移且一致：隐藏迁移/更新
  - 已迁移但不一致：显示“更新”
- **对比规则**：用于判断“是否一致”的 canonical 规则必须：
  - 保留用户配置字段（例如 `headers`/`env`）
  - 只做可解释的归一化（例如 enabled/disabled 表示、必要时推断 `type`）

## dont
- 不要假设所有 provider 都使用 `mcp_settings.json` 或 `mcpServers`。
- 不要在未实际验证/未打开链接的情况下声称“已按官方确认”。
- 不要默认提供“全部迁移”按钮（除非用户明确提出批量需求）。

## examples
- OpenCode：先确认配置文件 `~/.config/opencode/opencode.json`，然后确认顶层 key 是 `mcp`（不是 `mcpServers`），再改计数/读取/写入。
- 用户给了示例 JSON：优先按示例字段保留（如 `type`, `headers`, `env`），迁移时不要丢字段。

## exceptions
- 如果 provider 官方文档缺失或不清晰：才用“代码现状 + 用户实际文件”反推，并在 CHANGELOG 明确“推断依据与风险点”。

## validation
- UI：OpenCode/Codex/Claude 各自 MCP 列表数量正确；点击编辑打开正确文件。
- 迁移：单个 MCP 迁移后卡片隐藏“迁移”；修改 provider 配置后卡片显示“更新”；点击“更新”后恢复隐藏。
- 构建：`./build.sh` 通过（若需要在沙盒外运行，先说明原因再请求授权）。

