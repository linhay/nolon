# Codex Binary 下沉（Phase 1）

## 背景
- 目标：将 Codex 二进制管理相关核心能力逐步下沉到 `libs/Providers`，`nolon` app 层只做编排。
- 本轮采取“先下沉实现，再逐步切换调用”的策略，避免一次性跨模块改造导致全量回归风险。

## 本轮落地
- 新增库侧实现（`CodexProvider`）：
  - `libs/Providers/Sources/Providers/Codex/CodexBinaryManager.swift`
  - `libs/Providers/Sources/Providers/Codex/CodexBinaryManifest.swift`
  - `libs/Providers/Sources/Providers/Codex/STVersion.swift`
- app 侧保持现状可运行：
  - `nolon/Skills/Infrastructure/CodexBinaryManager.swift` 仍保留实现，避免当前 UI/测试大范围 import 变更。
  - 仅补充 `compareVersion` / `isStableVersion` 的 `public` 访问级别，便于后续跨模块调用。

## 验证
- `swift test --package-path libs/Providers` 通过。
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexBinaryAutoUpdateBehaviorTests -only-testing:nolonTests/CodexAuthServiceTests` 通过。

## 下一步（Phase 2）
- 将 app 层对 `CodexBinaryManager` 的直接引用迁移为 `import CodexProvider` 后调用库侧类型。
- 迁移顺序建议：
  1. `ProviderContentTabView` / `CodexBinaryConfigView` / `CodexAdvancedConfigView`
  2. `MainSplitView` / `ProviderDetailGridViewModel` / `UsageMonitorService`
  3. `nolonTests/CodexBinaryAutoUpdateBehaviorTests` 与相关测试 import 收敛
- 完成后删除 app 侧重复实现，保留单一来源（`libs/Providers`）。

## 第四十三轮推进（Binary 双实现清理 + 回归）
- BDD 场景：
  - Given app 与库都存在 Codex Binary 定义，When 执行下沉收敛，Then app 应仅依赖 `CodexProvider` 的单一实现来源。
- TDD 过程：
  - 先新增迁移守卫测试 `CodexBinaryDownsinkMigrationTests`，锁定 app 类型应与 `CodexProvider` 类型一致。
  - 清理后首次回归暴露 `String.nonEmpty` 被连带删除导致的编译失败（红灯）。
  - 最小修复：新增 `nolon/Skills/Models/String+Nolon.swift` 恢复公共扩展；`CodexBinaryAutoUpdateBehaviorTests` 显式 `import CodexProvider`；回归转绿。
- 代码变更：
  - 删除遗留重复实现：
    - `nolon/Skills/Infrastructure/CodexBinaryManager.swift`
    - `nolon/Skills/Models/CodexBinaryManifest.swift`
  - 新增：
    - `nolonTests/CodexBinaryDownsinkMigrationTests.swift`
    - `nolon/Skills/Models/String+Nolon.swift`
  - 调整：
    - `nolonTests/CodexBinaryAutoUpdateBehaviorTests.swift`（显式依赖库侧类型）
- 验证通过：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexBinaryDownsinkMigrationTests -only-testing:nolonTests/CodexBinaryAutoUpdateBehaviorTests -only-testing:nolonTests/CodexAuthServiceTests`
