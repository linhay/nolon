# Codex 全面支持功能规格

## 目标
- 在 Nolon 中提供对 Codex CLI 与 `codex app-server` 的完整支持。
- 保证职责边界清晰：`nolon` 只做编排，CLI/RPC 能力全部下沉到 `libs/Providers`。
- 支持账号运行时切换、会话解析、配置读取、用量统计与错误回退策略。

## 范围
- 包含：
  - Codex CLI command line options 封装（`CodexCLIKit`）
  - app-server JSON-RPC 会话封装（`JsonRPCKit` + `CodexAppServerKit`）
  - Provider 侧统一调用与运行时切换（`CodexProvider` / `ProviderUsage`）
  - Codex 生成文件解析（`auth.json`、`models_cache.json`、`history.jsonl`、`config.toml`、`managed_config.toml`、`sessions/**/*.jsonl`、`archived_sessions/**/*.jsonl`）
- 不包含：
  - 改造 Codex 官方二进制行为
  - 通过 app 层直接操纵 RPC 细节（禁止）

## 约束
- 使用真实 `codex` 二进制，不做本地协议“仿真替代”。
- 不依赖 provider 目录 `auth.json` 做激活判断；激活以 runtime + registry 为准。
- 生产代码禁止 `print()`，统一 `OSLog`。

## 验收标准（BDD）
1. Given 已安装真实 `codex`  
   When 调用封装后的 CLI 命令构建器  
   Then 参数渲染与官方命令行为一致（已覆盖命令集测试）。

2. Given app-server 正常启动  
   When 发起 `account/login/start`（`chatgptAuthTokens`）  
   Then 不重启子进程即可切换账号，并收到 `account/updated`。

3. Given provider 层请求账号/额度  
   When runtime service 可用  
   Then 走 RPC typed API；失败时按既定策略回退，不破坏主流程。

4. Given 读取 Codex 生成文件  
   When 解析 `response_item` / `event_msg` / `compacted` 等 rollout 事件  
   Then 输出 typed 结构，不丢失结构化字段（含 custom tool input/output）。

5. Given app 层需要打开 `nolon://` 或 `nln://` 链接  
   When URL 进入处理链路  
   Then 仅做协议归一化（转 `https://`）并交给业务层编排，无 RPC 逻辑泄漏到 app 层。

## 非功能要求
- 所有改动可通过自动化测试回归验证（`swift test --package-path libs/Providers` + 主工程构建脚本）。
- 结构保持可扩展：后续新增 app-server 方法应优先扩展 `CodexAppServerKit` typed API。
