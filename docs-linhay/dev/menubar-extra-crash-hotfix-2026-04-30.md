# MenuBarExtra Crash Hotfix

日期：2026-04-30

## 背景

`2.2.1` 虽然已经移除了 CloudKit / APS 相关能力，并修复了启动期 CloudKit `SIGTRAP`，但本地安装后仍会在运行时生成新的 `nolon-*.ips`。

## 现象

- 崩溃版本：`2.2.1 (202604301234)`
- 代表性报告：`~/Library/Logs/DiagnosticReports/nolon-2026-04-30-130240.ips`
- 关键栈：
  - `SwiftUI AppKitMainMenuItem.menuNeedsUpdate`
  - `SwiftUI PlatformItemList.update`
  - `AppKit NSContextMenuImpl`
  - `CoreFoundation -[NSTaggedPointerString hash]`

## 结论

当前更高概率的根因不再是 CloudKit，而是 `nolonApp.swift` 中的 `MenuBarExtra("nolon") { CodexQuickSwitchMenuBarView() }` 动态菜单内容，在 macOS 26.4.1 上触发了 SwiftUI/AppKit 菜单 diff 崩溃。

## 证据

1. 新崩溃报告已经不再经过 `CodexiCloudSyncService` 或 `CloudKit.framework`。
2. 删除 `MenuBarExtra` 场景后，本地 Debug 诊断版连续驻留且未生成新的 `nolon-*.ips`。
3. 基于同一修复重新打出的 `2.2.2` 安装到 `/Applications` 后，进程驻留超过 1 分钟，且未生成自安装时间之后的新崩溃报告。

## 热修复

- 临时下线菜单栏入口，移除 `MenuBarExtra` 场景。
- 版本提升到 `2.2.2 (202604301330)`。
- 重新使用 Xcode 官方签名链路生成并公证 `arm64` 安装包。

## 后续

- 如果要恢复菜单栏入口，需要单独针对 `CodexQuickSwitchMenuBarView` 做最小化回归，优先从动态 provider menu、动态列表刷新和嵌套 menu 结构入手。
