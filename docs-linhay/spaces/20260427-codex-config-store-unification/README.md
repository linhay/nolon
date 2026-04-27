# Codex config.toml 单一读写收拢

## 背景
- `config.toml` 当前被多个模块直接读写：模型切换、MCP 同步、relay provider patch、CLI 登录预处理、结构化高级配置保存。
- 各模块分别持有自己的读改写逻辑，容易基于旧快照覆盖别处刚写入的字段，最终表现为配置丢失。

## 目标
- 收拢 `config.toml` 到单一读写类，统一处理读取、按路径串行化的 read-modify-write、常见顶层键 patch，以及 provider id 解析。
- 将现有主要写路径迁移到统一 store，避免继续直接整文件 `overlay` / `write`。

## 范围
- `CodexBinaryManager`
- `MCPConfigManager`
- `CodexActiveProviderConfigManager`
- `NolonCodexCLI.prepareIsolatedLoginHome`
- Codex 相关 UI 的结构化配置保存与初始建档

## 验收标准
1. Given 不同模块先后更新同一个 `config.toml`，When 变更都通过统一 store 落盘，Then 先前未冲突的配置不会丢失。
2. Given 现有 `config.toml` 含自定义 top-level 键和 section，When 登录预处理或模型切换发生，Then 非受控配置保持不变。
3. Given MCP section、relay provider section 与模型偏好共同存在，When 任一模块更新自己的受控片段，Then 其他片段保持可读且不被整文件覆盖。

## 关联文档
- `libs/Providers/Sources/Providers/Codex/`
- `libs/Providers/Sources/NolonResourceKit/Infrastructure/MCPConfigManager.swift`
- `libs/Providers/Sources/ProviderUsage/CodexActiveProviderConfigManager.swift`
