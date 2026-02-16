# nolon codex binary switch

## 目标
- 提供交互式版本切换入口，用户可以从已安装/可下载列表中选择目标版本。

## BDD 场景
1. Given 用户在 TTY 终端运行 `nolon codex binary switch`，When 命令展示已安装与可下载版本列表，Then 用户输入序号可完成版本切换。
2. Given 用户选择已安装版本，When 执行切换，Then 仅激活该版本，不触发下载。
3. Given 用户选择未安装版本，When 执行切换，Then 先下载该版本并设置为默认版本。
4. Given 非 TTY 环境执行 `nolon codex binary switch`，When 未提供可交互输入，Then 返回 `invalid_arguments` 并提示使用 install/use 命令。
