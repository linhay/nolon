# Codex Advanced Config MainActor Deinit Crash（2026-03-02）

## 关联需求
- Feature 文档：`docs-linhay/spaces/codex-config-toml-phase1/README.md`

## 背景
- 单测 `CodexAdvancedConfigRoleDraftTests` 在释放 `CodexAdvancedConfigViewModel` 时触发运行时崩溃：
  - `libsystem_c.dylib: abort() called`
  - 栈中出现 `swift_task_deinitOnExecutorMainActorBackDeploy` 与 `CodexAdvancedConfigViewModel.__deallocating_deinit`

## BDD 场景
- Given：`@MainActor` 的 `CodexAdvancedConfigViewModel` 已创建并执行一次最小角色草稿操作。
- When：实例离开作用域并触发析构。
- Then：析构过程不应触发 `abort()` 或 malloc client bug。

## 修复策略（最小改动）
- 在 `CodexAdvancedConfigViewModel` 中显式添加：`nonisolated deinit {}`。
- 目的：绕开 MainActor back-deploy deinit 释放路径的崩溃点，保持现有行为和 API 不变。

## 回归测试
- 新增/保留测试：
  - `testBDD_GivenAdvancedConfig_WhenCreateEmptyRoleDraft_ThenNewRoleFieldsAreBlank`
  - `testBDD_GivenMainActorViewModel_WhenReleaseInstance_ThenDeinitDoesNotCrash`
- 验证命令：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-app -destination 'platform=macOS,arch=arm64' -only-testing:nolonTests/CodexAdvancedConfigRoleDraftTests -quiet`
- 结果：通过。
