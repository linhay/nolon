# 可 Fork 独立榜单模板（2026-03-03）

## 目标
- 提供一个可在 GitHub / GitLab 上直接 fork 的榜单模板仓库。
- 每个 fork 都是独立站点，不依赖中心服务。

## 范围
- 包含：submission 校验、快照聚合、静态站展示、GitHub/GitLab CI。
- 不包含：中心化 API、登录系统、跨仓聚合。

## Submission 契约
- 不包含 `platform`。
- 不包含 `rangeMode`。
- `points` 必须包含 `tool` 字段（如 `codex` / `gemini`）。

## BDD 验收
1. Given fork 后启用 CI + Pages，When 提交合法 submission，Then 站点展示更新后的榜单。
2. Given submission 缺少 `tool`，When CI 审计，Then 失败并阻止合并。
3. Given 同用户同日同工具重复提交，When 聚合快照，Then 仅最新记录生效。
4. Given 按工具筛选，When 切换到 `codex` 或 `gemini`，Then 展示对应工具榜单。
