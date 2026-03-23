# 插件管理（XcodeMCPKit）技术设计

## 分层
- SDK: `NolonResourceKit.XcodeMCPKitReleaseChecker`
  - 调用 GitHub Releases API
  - 过滤 `draft/prerelease`
  - 语义化版本比较（`STVersion`）
- App: `PluginManagementViewModel` + `PluginManagementView`
  - 读取本地安装版本（`~/.nolon/plugins/xcodemcpkit/installed_version.txt`）
  - 调用 SDK 检测是否可升级
  - 命中升级时显示“升级”按钮

## 关键约束
- 只使用 `linhay/XcodeMCPKit` 发布源。
- 忽略 pre-release 版本，不触发升级提示。
- 插件管理是主导航独立页面（左侧“Tools/插件管理”入口），不挂载在 Provider Tabs，也不属于 `mcp` 页面。

## 测试
- SDK 单测：
  - 过滤 pre-release
  - 低版本安装时标记 `hasUpgrade = true`
- App 单测：
  - 进入页面后可得插件信息
  - pre-release-only 不显示升级
