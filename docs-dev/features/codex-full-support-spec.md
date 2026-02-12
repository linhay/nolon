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
  - 解析与存储路径能力统一到 STFilePath（优先 `STFile` / `STFolder` / `STPath`，保留 URL 兼容入口）
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

6. Given Provider 层读取/写入 token 账号与 Codex 生成文件  
   When 调用 `FileTokenAccountStore`、`CodexModelsCache`、`CodexGeneratedFilesParser`  
   Then 优先走 STFilePath 类型入口（`STFile`/`STFolder`/`STPath`），并与 URL 旧入口行为一致。

7. Given Provider 层需要推导 `CODEX_HOME` 或发起 `codex login`  
   When 调用 `CodexCommandExecutor` / `CodexLoginRunner`  
   Then 支持 `STFolder` 类型入口（URL 入口兼容），避免上层依赖裸路径字符串或本地 URL 拼接。

8. Given Provider 层执行 CLI 探测/TTY 命令  
   When 调用 `TTYCommandRunner.which` 与 `run`  
   Then 本地可执行文件判定与 executable 路径传递优先走 STFilePath，并保持现有命令行为不变。

9. Given ProviderCatalog 需要暴露 provider 路径给上层编排  
   When 读取 `Provider.path/pathURL` 与 `additionalPaths/additionalPathURLs`  
   Then 以 STPath 作为内部语义基线，同时保留 URL 兼容访问。

10. Given CostUsage 存储未显式传入 cacheRoot  
    When 走默认缓存目录推导  
    Then 通过 STFilePath 组合路径定位到 `~/Library/Caches/CodexBar/cost-usage/*.json`，不依赖 `FileManager` 目录枚举。

5. Given app 层需要打开 `nolon://` 或 `nln://` 链接  
   When URL 进入处理链路  
   Then 仅做协议归一化（转 `https://`）并交给业务层编排，无 RPC 逻辑泄漏到 app 层。

## 非功能要求
- 所有改动可通过自动化测试回归验证（`swift test --package-path libs/Providers` + 主工程构建脚本）。
- 结构保持可扩展：后续新增 app-server 方法应优先扩展 `CodexAppServerKit` typed API。
