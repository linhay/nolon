# Codex 菜单栏快速切号（2026-03-18）

## 1. 范围
- 新增 macOS `MenuBarExtra` 入口，提供 Codex 账号快速切换面板。
- 支持显示账号额度摘要（短窗口 + weekly）。
- 支持菜单动作：刷新额度、删除账号、添加 Codex 账号（跳转主窗口账号与用量页）、打开 `auth.json`、打开 `config.toml`、退出。

## 2. 不包含
- 不新增独立登录弹窗流程（沿用主界面已有账号管理流）。
- 不改动主界面 Provider Usage 信息结构与排序策略。

## 3. BDD 验收场景
1. Given 存在 `codex` 与 `codexXcode` 两类 provider，When 菜单栏解析目标 provider，Then 优先选中 `codex`。
2. Given 账号存在 5h 与 weekly 窗口，When 渲染摘要文案，Then 显示 `5h xx% (HH:mm) · weekly yy% (MM/dd HH:mm)`。
3. Given 用户在菜单栏点击某账号，When 该账号可切换，Then 激活账号并刷新列表状态。
4. Given 用户点击“添加 Codex 账号”，When 主窗口打开，Then 跳转到对应 provider 的“账号与用量”Tab。

## 4. 测试
- `nolonTests/CodexQuickSwitchMenuBarSupportTests.swift`
  - `testBDD_GivenUsageWindows_WhenFormattingSummaryLine_ThenPrefersFiveHourAndWeeklyWindows`
  - `testBDD_GivenProviderList_WhenResolvingCodexProvider_ThenPrefersCodexTemplate`
- 通过命令：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexQuickSwitchMenuBarSupportTests`
