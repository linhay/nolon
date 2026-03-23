# CLI Plugin 管理（2026-03-04）

## 背景
用户要求先完成 `cli plugin`，再做 app；明确 `cli mcp` 不是本轮目标入口。

## 目标
新增 `nolon plugin` 命令族，覆盖插件管理核心流程：
1. `list`
2. `status`
3. `install`
4. `upgrade`
5. `uninstall`
6. `start`
7. `stop`

首期仅支持插件：`xcodemcpkit`。

## BDD 验收场景
1. Given 执行 `nolon plugin --help`，When CLI 输出帮助，Then 可见 install/upgrade/uninstall/start/stop 子命令。
2. Given 初始未安装版本文件，When 执行 `nolon plugin install --name xcodemcpkit --provider codex --version v0.3.6 --force`，Then 返回安装成功，且 `status` 显示 installed 为 `v0.3.6`。
3. Given 已安装 `v0.3.6`，When 执行 `nolon plugin upgrade --name xcodemcpkit --provider codex --to-version v0.3.7 --force`，Then 返回升级成功，且 `status` 显示 installed 为 `v0.3.7`。
4. Given 已安装，When 执行 `nolon plugin uninstall --name xcodemcpkit --provider codex --force`，Then 返回卸载成功，且 `status` 显示 installed 为 `-`。

## 非目标
1. 不在本轮实现插件二进制下载/替换（仅管理 provider MCP server 配置与本地版本标记）。
2. 不在本轮引入多插件动态注册。
