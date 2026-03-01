# Codex Config.toml 一期规格（Features + 配置）

## 背景
一期目标是把 Codex 的配置支持统一收敛到 Provider `Advanced` 页面，重点覆盖 `multi-agent`，并纳入基础配置项（`common configuration options`）和 `features` 管理。

来源限制：
- 官方文档：
  - https://developers.openai.com/codex/config-basic#feature-flags
  - https://developers.openai.com/codex/config-basic#common-configuration-options
  - https://developers.openai.com/codex/multi-agent
- Codex 源码（本仓库镜像）：
  - `reference-projects/codex/codex-rs/core/src/config/mod.rs`
  - `reference-projects/codex/codex-rs/core/src/features.rs`

## 范围
- 包含：
  - `config.toml` 的完整读取解析能力（SDK）。
  - `Advanced` 页面的 features 管理与说明。
  - `multi-agent` 配置（`[features].multi_agent` + `[agents]` 关键字段 + roles）。
  - common configuration options 的结构化配置入口。
  - 提供独立文档页区域，并可一键跳转官方文档锚点。
  - 提供 TOML 原文编辑兜底，确保完整配置可覆盖。
- 不包含：
  - 新增独立 Provider tab（一期维持在 `Advanced`）。
  - 修改 Codex 官方行为或协议。

## BDD 验收
1. Given 用户打开 Codex Provider 的 `Advanced`
   When 页面加载配置
   Then 可以看到 Features 列表、关键说明和文档跳转按钮。

2. Given 用户启用 `multi-agent`
   When 保存配置
   Then `config.toml` 中 `[features].multi_agent = true` 生效。

3. Given 用户需要配置多代理角色
   When 在结构化界面编辑 `[agents]`（含 roles）并保存
   Then `agents.max_threads` / `agents.max_depth` / `agents.<role>` 字段写回配置文件。

4. Given 用户配置 common options
   When 设置 `approval_policy`、`sandbox_mode`、`web_search`、`model_reasoning_effort` 等并保存
   Then 对应配置键写回并可重新解析。

5. Given 用户有高级或暂未结构化覆盖的配置项
   When 打开 TOML 编辑器直接编辑并保存
   Then 能通过 SDK 校验并写回 `config.toml`。

## DoD
- SDK 测试覆盖 `feature flags + common options + agents roles` 解析。
- App 层有可交互的配置区、文档跳转按钮、TOML 兜底编辑。
- 回归测试通过（至少 Providers package tests + 受影响的 nolon tests）。
