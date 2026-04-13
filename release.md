# Nolon 2.1.12

## Highlights
- Codex gateway 已从主工程移除，准备迁入独立 SPM；主仓库不再提供 gateway runtime、CLI 命令或 UI 管理入口。
- Direct auto-switch 仍保留在主工程中，继续负责低额度场景下的本地自动切号。
- Runtime、CLI、ProviderUsage 与共享 UI 已同步清理网关实现和对应依赖，避免后续继续耦合到主仓库。
