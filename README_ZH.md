# Nolon

[English](README.md) | 中文

Nolon 是一款 macOS 上的 AI 编程工作区管理器。

你可以在 **Codex**、**Claude Code**、**Cursor** 等 20+ 工具之间共享一套配置，而不必每个工具重复折腾。

## 为什么用 Nolon

* 在 `~/.nolon/skills` 维护统一事实源
* 统一管理 **Skills**、**Provider**、**MCP**
* 在不同 AI 编程工具间切换时保持一致工作流
* 应用更新与内容更新都可持续维护

## 下载

* 最新版本：[v1.3.5](https://github.com/linhay/nolon/releases/latest)
* Appcast（Sparkle）：[appcast.xml](https://linhay.github.io/nolon/appcast.xml)

## 核心能力

* 支持 25+ AI 编程助手 Provider
* 按 Provider 选择安装方式：**软链接** 或 **复制**
* 从 [Clawdhub](https://clawdhub.com) 远程发现并安装 Skills
* MCP 配置管理与远程 MCP 安装流程
* 对未纳管/孤立 Skills 的迁移助手
* 损坏链接与安装漂移的健康检查和修复
* Skills 内容更新检查与应用内更新

## 常见工作流

1. 导入或同步 Skills 到 Nolon。
2. 安装到一个或多个 Provider。
3. 管理 MCP 与 Provider 专属配置。
4. 发现漂移后执行迁移/修复。
5. 通过内置更新链路保持应用与内容最新。

## 构建（开发者）

```bash
git submodule update --init --recursive
./build.sh
```

或：

```bash
xcodebuild -project nolon.xcodeproj -scheme nolon -configuration Release
```

## 环境要求

* macOS 15.0+
* Xcode 16.0+（用于构建）
