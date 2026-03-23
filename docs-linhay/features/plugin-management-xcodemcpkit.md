# 插件管理页面（XcodeMCPKit）

## 目标
- 插件管理是独立页面，不属于 MCP 页面。
- 插件列表内置 `XcodeMCPKit`。
- 进入插件页面时检查 GitHub 最新稳定版（忽略 pre-release）。
- 当检测到 `latest > installed` 时显示“升级”按钮。

## BDD 验收场景
1. Given 用户进入左侧主导航的“插件管理”页面，When 页面加载完成，Then 能看到 `XcodeMCPKit` 条目。
2. Given GitHub 存在高于本地安装版本的稳定版，When 页面加载，Then 显示“升级”按钮。
3. Given GitHub 仅存在 pre-release 新版本，When 页面加载，Then 不显示“升级”按钮。
4. Given 用户点击“升级”，When 操作触发，Then 打开 `https://github.com/linhay/XcodeMCPKit/releases`。

## 范围
- 首期仅支持 `XcodeMCPKit` 一个插件条目。
- 当前实现以版本检测和升级入口为主，不改动现有 MCP 页面交互。
