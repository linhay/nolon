# Codex 导入账号无法唤起 Finder：修复说明（2026-03-11）

## 背景
- 问题：`账号与用量 -> 导入 -> 导入账号 -> 选择文件` 点击后没有唤起 Finder。
- 影响：用户无法从导入弹窗继续选择 `auth.json` / `.zip` 文件，只能依赖拖拽或粘贴。

## 原因
- `选择文件` 按钮位于 `CodexImportSheet` 内。
- 实际文件选择能力使用的是父视图 `ProviderUsageView` 上的 `.fileImporter(...)`。
- 在 macOS 的这一层级下，sheet 内触发父层 `fileImporter` 存在不稳定/不弹出的表现，导致用户看起来像“按钮没反应”。

## 修复
- 将导入弹窗内的“选择文件”从父层 `.fileImporter(...)` 改为直接使用 `NSOpenPanel`。
- 仍保持原有导入能力：
  - 支持多选
  - 支持 `.json` / `.zip`
  - 选择后继续复用现有 `handleCodexImportURLs` 校验与连接测试链路
- 这样文件选择行为与当前 sheet 处于同一展示层级，避免 Finder 不弹出。

## 测试
- 新增 BDD 测试：
  - 当 open panel 返回文件时，开始校验并生成候选账号。
  - 当 open panel 取消时，不污染现有候选状态。
- 已运行：
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -derivedDataPath /tmp/nolon-codex-import-fix test -only-testing:nolonTests/CodexUsageTabPresentationTests`
