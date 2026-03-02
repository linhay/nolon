# Nolon

[English](README.md) | 中文

Nolon 是一款面向 macOS 的 AI 编程工具工作区编排器。

它在 `~/.nolon/skills` 维护统一工作区，再按各 Provider 特性分发到 Codex、Claude Code、Cursor 及 25+ Provider。

## 下载

- 最新版本：[v1.3.5](https://github.com/linhay/nolon/releases/latest)
- Sparkle 更新源：[appcast.xml](https://linhay.github.io/nolon/appcast.xml)

## 当前 App 形态

### 1）主工作区（常驻）

Nolon 采用三栏工作区：
- Provider 侧边栏
- Provider 内容标签栏
- 详情网格/内容面板

### 2）资源中心（Overlay）

点击云按钮打开资源中心叠层，用于远程发现与安装：
- Skills
- Workflows
- MCPs

### 3）Provider 专属能力面

当前标签页按能力动态呈现：
- 基础标签：`Skills`、`Workflows`、`MCP`
- Codex 标签：`Rules`、`Agents`、`Binary`、`Advanced`、`Usage`
- Vendor 扩展标签（可用时）：`Accounts`、`Usage` 等

## 核心能力

- 统一管理 25+ AI 编程助手 Provider。
- 在 `~/.nolon/skills` 维护单一事实源。
- 从 [Clawdhub](https://clawdhub.com) 远程发现与安装资源。
- MCP 配置管理与安装流程。
- 面向 Codex 的账号/用量与高级配置链路。
- 未纳管/孤立 Skills 的迁移助手。
- 损坏链接与安装漂移的健康检查和修复。

## 典型工作流

1. 在主工作区选择目标 Provider。
2. 打开资源中心安装 Skills/Workflows/MCPs。
3. 在 Provider 专属标签中完成配置（如 Codex `Advanced`/`Usage`）。
4. 发现漂移后执行迁移与修复检查。
5. 通过内置更新链路保持应用与资源最新。

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

- macOS 15.0+
- Xcode 16.0+（本地构建）

## 文档索引

- 需求与规格：[`docs-dev/features/`](docs-dev/features/)
- 研发文档：[`docs-dev/dev/`](docs-dev/dev/)
- API 文档：[`docs-dev/api/`](docs-dev/api/)
- 运维与发布：[`docs-dev/ops/`](docs-dev/ops/)

## 分支变更说明

当前分支合并说明见：
- [`docs-dev/ops/main-merge-notes-2026-02-27.md`](docs-dev/ops/main-merge-notes-2026-02-27.md)
