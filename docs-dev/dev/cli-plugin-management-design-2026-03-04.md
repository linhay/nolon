# CLI Plugin 管理设计（2026-03-04）

## 入口与路由
1. `NolonRootCommand` 新增 `NolonPluginRootCommand`。
2. `NolonCoreCLIArgumentParser` 新增 plugin 子命令结构并映射到 `NolonCoreCLICommand`。
3. `NolonCodexCLI` 的 core-route、help target/type 路由支持 `plugin`。
4. `NolonCoreCLIHelp` 增加 `plugin` 帮助文本。

## 命令模型
新增命令：
1. `.pluginList`
2. `.pluginStatus(name:)`
3. `.pluginInstall(name:provider:version:force:)`
4. `.pluginUninstall(name:provider:force:)`
5. `.pluginUpgrade(name:provider:toVersion:force:)`
6. `.pluginStart(name:forceRestart:)`
7. `.pluginStop(name:force:)`

## 执行策略
1. 插件名白名单：仅 `xcodemcpkit`。
2. install/upgrade：
   - 通过 `service.upsertMcpServer(provider:name:"xcode", command:"xcode-mcp-proxy")` 写入 provider MCP server。
   - 版本写入 `~/.nolon/plugins/xcodemcpkit/installed_version.txt`（尊重 `NOLON_HOME`）。
3. uninstall：
   - 停止 `xcode-mcp-proxy-server`（SIGTERM/SIGKILL）。
   - `service.removeMcpServer(provider:name:"xcode")`。
   - 删除 `installed_version.txt`。
4. status/list：
   - 读取版本文件。
   - 检测 `xcode-mcp-proxy` 与 `xcode-mcp-proxy-server` 是否在 PATH。
   - 检测运行态（`ps -axo pid=,command=` 扫描 server pid）。

## 稳定性决策
1. 默认离线：release 检查默认关闭，避免 CLI 在弱网/异常网络下阻塞。
2. 通过环境变量 `NOLON_PLUGIN_CHECK_LATEST=1` 显式开启在线检查。
3. 修复 `ps` 管道读取顺序，避免 wait-before-read 导致潜在死锁。

## 测试
1. `NolonCoreCLIKitTests` 新增 parser 用例：
   - `parse plugin install command`
   - `parse plugin stop command`
2. 全量筛选测试：`swift test --package-path libs/Providers --filter NolonCoreCLIKitTests --parallel`。

## 2026-03-04 二次实现（全局资源中心语义）
1. plugin install/upgrade/uninstall 不再写当前 provider 的 MCP server。
2. 改为写入资源中心-全局路径：`~/.nolon/mcps/xcodemcpkit.json`（尊重 `NOLON_HOME`）。
3. 全局 JSON 内新增标记字段：
   - `nolon_plugin.plugin_id`
   - `nolon_plugin.managed`
   - `nolon_plugin.schema_version`
   - `nolon_plugin.installed_by`
   - `nolon_plugin.installed_at`
4. uninstall 安全策略：若全局条目存在但无 plugin marker 或 `plugin_id` 不匹配，返回 `plugin_not_managed_by_nolon`，拒绝删除。
5. 能力解耦：引入 plugin capability（`mcp_global_install` / `runtime_control`），为“插件不一定对应 MCP”预留扩展位。
6. 修复运行时误杀：`plugin uninstall` 先做 marker 校验，再 stop；进程匹配仅匹配可执行命令并跳过当前 PID。

## 验证结果（源码 CLI）
1. `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests --parallel` 通过。
2. `swift run --package-path libs/Providers nolon plugin install/upgrade/uninstall`：通过。
3. 手工构造非 plugin 管理全局 JSON 后执行 uninstall：返回 `plugin_not_managed_by_nolon`，文件保留。
4. 注意：`~/.nolon/bin/nolon` 若未重装会是旧二进制，需重新构建/发布后才具备新行为。

## 2026-03-04 修复补充（运行态 stop 时序）
1. `plugin stop` 发送信号后增加短轮询等待退出（默认 800ms），降低连续 stop 的竞态噪声。
2. 进程匹配补充 shell 脚本形式（`sh/bash/zsh/dash <script>`），确保 `start` 二次调用可正确识别 `already running`。
3. 新增回归：脚本运行态下 `start/stop` 幂等测试。

## 2026-03-04 继续测试修复（异常 JSON）
1. 问题：全局 MCP 文件损坏 JSON 时，卸载返回 `execution_failed`，语义不稳定。
2. 修复：`readPluginMarker` 对 JSON 解析失败按“存在但非 plugin 管理”处理。
3. 结果：`plugin uninstall` 在损坏 JSON 场景统一返回 `plugin_not_managed_by_nolon`，并拒绝删除。
4. 新增测试：`runner plugin uninstall treats invalid global json as unmanaged and blocks deletion`。

## 2026-03-04 修复补充（`--json` 前置路由）
1. 问题：`nolon --json plugin ...` 会误走 codex executor，报 `Unsupported parsed command type: NolonPlugin*Command`。
2. 根因：`NolonCLIEntrypoint.shouldRouteToCoreCLI` 只看 `arguments.first`，首参为 `--json` 时无法识别 root=plugin。
3. 修复：路由判断前先过滤 `--json`，再识别 root 命令。
4. 回归测试：
- `json flag before plugin command routes to core CLI`
- `json flag after plugin command routes to core CLI`
5. 实测：`swift run nolon --json plugin status/install/uninstall --name xcodemcpkit` 均返回 `ok=true`。
