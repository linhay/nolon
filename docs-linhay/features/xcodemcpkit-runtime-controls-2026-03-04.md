# XcodeMCPKit 运行控制（2026-03-04）

## 目标
在 Plugin Management 中为 XcodeMCPKit 提供应用内启动/停止按钮，支持会话内守护进程管理。

## 范围
1. 插件页显示运行状态。
2. 提供 Start/Stop/Retry Start 行为。
3. 保持原有 Upgrade/Open Releases 行为。
4. 插件安装状态通过读取二进制 `xcodemcpkit` 是否存在判定。
5. 版本展示读取 `installed_version.txt`，但仅在已安装时展示。
6. 未安装时主按钮执行应用内安装（下载 release 包、解压并写入本地可执行文件）。
7. 已安装且有新版本时，Upgrade 按钮执行应用内升级（不跳转浏览器）。

## 非范围
1. 不引入 launch agent 持久保活。
2. 不在资源中心 MCP 卡片增加启动入口。

## 验收
1. 未运行时显示 Start，点击后进入 Running。
2. 运行中显示 Stop，点击后回到 Stopped。
3. 缺少 `xcodemcpkit` 时展示失败信息。
4. 二进制存在时显示 `Status: Installed`；不存在时显示 `Status: Not Installed`。
5. 二进制不存在即使版本文件有值，也不显示 Installed 版本号。
6. 二进制不存在时主按钮显示 `Install`；点击后在应用内完成下载+安装并刷新为 Installed。
7. 存在可升级版本时按钮显示 `Upgrade`；点击后在应用内升级并刷新为最新版本。

## 2026-03-04 增补验收（SKProcessRunner）
1. Runtime 控制实现改为基于 `SKProcessRunner`（`SKProcessPipeSession`），不再直接持有 `Process`。
2. force stop 通过进程信号能力实现，支持 SIGKILL 兜底。
3. 对应单测覆盖 start/stop/异常退出三类核心路径。
