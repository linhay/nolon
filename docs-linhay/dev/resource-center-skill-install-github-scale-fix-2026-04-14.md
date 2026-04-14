# Resource Center GitHub Skill 安装修复执行说明（2026-04-14）

## 关联文档
- `docs-linhay/features/skill-install-nonstandard-symlink-layout-2026-03-03.md`
- `docs-linhay/debate/20260414/resource-center/20260414-skill-install-github-scale-v01.md`

## 背景
- 用户反馈：从 GitHub 仓库安装 `scale` 这类 skill 时，界面会长时间显示“安装中”，随后安装失败。
- 本次问题不是单点故障，而是两条链路叠加：
  1. 安装器在 linked-root provider 布局下可能把实体 skill 目录错误地重新做成 skill 级符号链接。
  2. Resource Center 在安装失败后没有立即消费错误，导致真实失败被 timeout 表象掩盖。

## 设计摘要
1. 安装链路统一收口到 `SkillInstaller.installSkillContent(...)`。
2. linked-root 判断升级为真实路径解析：
- 比较 provider root 与 source parent 在 `resolvingSymlinksInPath()` 后的真实路径。
- 不只覆盖 `defaultSkillsPath` 自身是符号链接的情况，也覆盖父目录间接链接布局。
3. linked-root 场景改为实体化复制：
- 使用 `SkillContentMaterializer.copyMaterializingSymlinks(...)`。
- 保证 `~/.nolon/skills/<slug>` 最终是实体目录，而不是指回仓库的符号链接。
4. CLI/维护链路与 App 安装链路对齐：
- `ProviderSkillMaintenanceService` 使用相同的真实路径判断逻辑。
5. Resource Center 统一失败状态机：
- 主列表、workflow detail sheet、MCP detail sheet、remote skill detail window 全部走 `begin*Install(...)`。
- 安装回调改为 `async throws`，失败时立即清除 pending 并回填真实错误。

## 关键文件
1. `libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift`
2. `libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillMaintenanceService.swift`
3. `nolon/Skills/Domain/App/Core/MainSplitView.swift`
4. `nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCatalogGridView.swift`
5. `nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCenterView.swift`
6. `nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCenterWindowCoordinator.swift`
7. `nolonTests/SkillInstallerTests.swift`
8. `nolonTests/ResourceCatalogGridViewInstallStateTests.swift`

## BDD 验收映射
1. `Given linked-root provider layout when installing local skill then global skill remains a real directory`
- 对应 `SkillInstallerTests.testBDD_GivenLinkedProviderRoot_WhenInstallLocal_ThenKeepGlobalSkillAsRealDirectory`
2. `Given parent-linked provider layout when installing local skill then global skill remains a real directory`
- 对应 `SkillInstallerTests.testBDD_GivenParentLinkedProviderRoot_WhenInstallLocal_ThenKeepGlobalSkillAsRealDirectory`
3. `Given install failure when Resource Center is pending then pending is removed and real error is shown`
- 对应 `ResourceCatalogGridViewInstallStateTests.testApplyInstallFailure_RemovesPendingAndStoresErrorMessage`
4. `Given empty error description when install fails then UI falls back to retry hint`
- 对应 `ResourceCatalogGridViewInstallStateTests.testInstallFailureMessage_FallsBackToRetryHintWhenErrorDescriptionIsEmpty`

## 执行要点
1. 先保证安装器和维护链路的 linked-root 判定逻辑一致，避免 App/CLI 分叉。
2. 再统一 Resource Center 各入口的错误传播，不允许 detail 入口继续使用 `try? await` 吞错。
3. 只保留 timeout 作为兜底机制，不再让 timeout 成为默认失败表象。
4. 所有新增边界都必须由定向测试锁住，再进入收尾文档阶段。

## 验证
- 命令：
```bash
xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/SkillInstallerTests -only-testing:nolonTests/ResourceCatalogGridViewInstallStateTests
```
- 最近一次结果：
  - 时间：2026-04-14 17:36（Asia/Shanghai）
  - 结果：10 个测试全部通过，0 失败

## 已知非阻塞风险
1. 更复杂的大小写归一化、跨挂载点路径判断仍可继续增强。
2. `copyMaterializingSymlinks(...)` 在超大仓库下可能放大磁盘占用和安装耗时。
3. 极慢安装场景下，timeout 文案仍可能先于更丰富的进度反馈出现。
