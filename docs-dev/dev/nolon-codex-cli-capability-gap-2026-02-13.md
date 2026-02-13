# Nolon Codex CLI 能力现状与补强清单（2026-02-13）

## 1. 目标
- 让 `nolon` 成为稳定单入口 CLI。
- Codex 能力细节继续下沉到 `libs/Providers`，App 仅做编排和 UI。

## 2. 当前已具备能力（libs/Providers）

### 2.1 命令面
- `nolon codex auth list|status|activate|login|delete`
- `nolon codex binary list|current|install|use|doctor`
- `nolon codex status probe`

### 2.2 参数/错误语义
- 使用 `ArgumentParser` 命令树（root/group/action）。
- 结构化错误 JSON 输出（`ok:false` + 业务错误码）。
- 空参数输出 help（`exitCode=0`），业务错误仍保持 JSON 错误。

### 2.3 兼容与解析
- `CodexGeneratedFiles` 已支持 `response_item/event_msg/compacted`。
- `event_msg` 已覆盖 `mcp_startup_update|mcp_startup_complete` 等兼容事件。
- `event_msg` 类型常量已收敛为可扩展结构（避免分散硬编码）。

### 2.4 可测试性
- 关键 CLI 路由、help、参数校验、服务层行为已具备自动化测试。
- `NOLON_HOME` 已支持隔离目录测试。

## 3. 主要缺口（按优先级）

### P0
1. 会话事件与 codex 源继续对齐
- 对 `libs/codex` 新增 `event_msg/response_item` 建立增量同步机制（清单 + 测试基线）。
- 避免后续 schema 漂移导致 silently fallback 到 `.other`。

2. App 侧残余编排收口
- 确认 nolon app 不再持有 auth/binary 细节实现。
- 仅保留调用 `NolonCoreCLIKit` / Provider facade。

### P1
1. CLI 打包/安装 E2E
- 覆盖 `scripts/install-nolon-cli.sh` 的实际可执行验证：
  - 安装后 `nolon --help`
  - `nolon codex --help`
  - `NOLON_HOME` 隔离多实例

2. 输出契约稳定性
- 为 CLI JSON 输出建立 schema snapshot（或 golden file）测试。
- 防止字段变更影响 UI/外部调用方。

### P2
1. STFilePath 渐进替换
- 新增路径逻辑优先 `STFolder/STFile/STPath`。
- 旧代码按模块渐进替换，避免一次性大改。

## 4. BDD 验收场景（下一阶段）
1. 当 codex 新增事件类型时，解析器应在测试中显式暴露差异并补齐映射。
2. 当用户在隔离目录安装 CLI 时，不影响默认 `~/.nolon` 数据。
3. 当输出 JSON 契约升级时，现有消费者（App/UI）不回归。

## 5. 推荐下一提交序列
1. `test(codex): add schema drift guard for event_msg/response_item`
2. `feat(codex): sync parser compatibility with latest codex protocol`
3. `test(cli): add install script e2e for NOLON_HOME isolated roots`
4. `docs(dev): update codex cli capability gap and rollout status`
