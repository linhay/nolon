# Skill 安装异常 Debate（2026-04-14）

关联文档：
- `docs-linhay/features/skill-install-nonstandard-symlink-layout-2026-03-03.md`

## 辩论背景
- 用户反馈：从 GitHub 仓库安装 `scale` 这类 skill 时，界面会长时间停留在“安装中”，随后才报错。
- 当前问题同时涉及两条链路：
  - 安装落地链路：GitHub/local repo skill 最终如何写入 `~/.nolon/skills/<slug>` 与 provider `skills` 目录。
  - UI 状态链路：安装失败后，Resource Center 何时把错误回传给界面。
- 本轮目标不是重做整个资源中心，而是先确认这次 `scale` 失败的真正根因，并补齐最小可验证修复。

涉及代码：
- `libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift`
- `libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillMaintenanceService.swift`
- `nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCatalogGridView.swift`
- `nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCenterView.swift`
- `nolon/Skills/Domain/App/Core/MainSplitView.swift`
- `nolonTests/SkillInstallerTests.swift`
- `nolonTests/ResourceCatalogGridViewInstallStateTests.swift`

## 参与者观点
- `Vector Tide（Codex）`
  - 这是两个问题叠加后的表象，不是单点故障。
  - 如果只修 UI，不修安装器，`scale` 仍然会装坏。
  - 如果只修安装器，不修 UI，用户仍会看到长时间“安装中”才失败，误导排障方向。

## Round 1（2026-04-14 15:30）

### Debate 1：GitHub 仓库扫描是否把错误路径交给了安装器

#### 现状
- `RepositorySyncOrchestrator` 与 `RemoteRepositorySidebarViewModel` 会把候选 skill 目录保存到 `skillsPaths`。
- `LocalFolderRepository.parseSkill` 解析 `SKILL.md` 后，把实际 skill 目录写入 `RemoteSkill.localPath`。
- `RemoteInstallOrchestrator.installSkill` 对 Git/local repo 资源会走 `SkillInstaller.installLocal(from:skill.localPath, ...)`。

#### 观点
- 扫描链路整体是通的，`scale` 的 `localPath` 不是主要嫌疑点。
- 失败更像发生在“安装落地”阶段，而不是“仓库发现”阶段。

#### 结论
- 仓库扫描链路不是本次主因，不在第一优先级修复范围内。

### Debate 2：`SkillInstaller` 是否缺少 linked-root 保护

#### 现状
- CLI/维护链路 `ProviderSkillMaintenanceService.installSkillInternal` 已经处理过一种特殊场景：
  - provider 的 `skills` 根目录本身是指向 `~/.nolon/skills` 的符号链接。
- App 内使用的 `SkillInstaller.install(skill:to:)` 原先没有这层保护。
- 在该场景下，若继续按 `installMethod == .symlink` 处理，容易在全局根目录内再次生成 skill 级符号链接，最终把刚复制进去的实体目录覆盖成错误链接。

#### 观点
- 这与 `docs-linhay/features/skill-install-nonstandard-symlink-layout-2026-03-03.md` 的第 4 条规则直接冲突。
- `scale` 这类从 GitHub/local repo 导入的 skill，最容易触发该路径，因为它们先进入全局缓存，再按 provider 安装。

#### 结论
- 这是本次安装失败的核心根因。
- 必须把 `ProviderSkillMaintenanceService` 中的 linked-root 保护下沉到 `SkillInstaller` 公共安装路径，避免 App 与 CLI 行为分叉。

## Round 2（2026-04-14 15:50）

### Debate 3：为什么用户看到的是“长时间安装中”，而不是立刻失败

#### 现状
- `ResourceCatalogGridView` 通过 `pendingSkillInstalls` / `pendingWorkflowInstalls` / `pendingMcpInstalls` 控制“安装中”状态。
- 原实现里，`onInstall` / `onInstallWorkflow` / `onInstallMCP` 是同步闭包。
- 安装失败不会立即回写到 `skillInstallErrors`，而是等到 45 秒 timeout 后才移除 pending，并显示统一文案 `Install timed out. Click Retry.`。

#### 观点
- 这会把真实错误伪装成“超时”，导致用户和维护者都误判问题位置。
- 即使安装器已经抛出准确错误，UI 也没有第一时间消费它。

#### 结论
- UI 状态机是本次“体验层根因”。
- 安装回调需要改为 `async throws`，让失败可以即时打断 pending 状态并回填真实错误。

## Round 3（2026-04-14 16:10）

### Debate 4：修复方案是否足够小且可验证

#### 最终修复
1. `SkillInstaller`
   - 新增统一的 `installSkillContent(...)`，集中处理 provider 安装落地。
   - 新增 `resolvedLinkedProviderRoot(...)` 与 `linkedProviderTarget(...)`。
   - 在 linked-root 场景下：
     - 不再在全局 skills 根目录内创建 skill 级符号链接。
     - 直接把 skill 内容物化复制到最终全局目录，保证 `~/.nolon/skills/<slug>` 是实体目录。
2. Resource Center
   - `onInstall` / `onInstallWorkflow` / `onInstallMCP` 改为 `async throws`。
   - 安装失败时立即执行 `applyInstallFailure(...)`：
     - 移除 pending
     - 写入真实错误文案
   - 保留 timeout 作为兜底，但不再把所有失败都伪装成 timeout。
3. 测试
   - `SkillInstallerTests`
     - 新增 linked-root 回归测试，覆盖 `scale` 的实体目录落地要求。
   - `ResourceCatalogGridViewInstallStateTests`
     - 覆盖失败后 pending 清理与错误文案兜底逻辑。

#### 验证结果
- 2026-04-14 16:14（Asia/Shanghai）执行：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/SkillInstallerTests -only-testing:nolonTests/ResourceCatalogGridViewInstallStateTests`
- 结果：
  - `9` 个测试全部通过。

#### 残余风险
- 这次只做了定向测试，没有全量回归 Resource Center 的所有远程安装路径。
- Resource detail/card 上仍有少数安装入口通过额外 `Task` 包装调用；当前主安装流程已可正确抛错，但后续仍值得统一收口，避免再次出现局部吞错。

## 结论与行动项
- 结论：
  - `scale` 安装失败的主根因，是 `SkillInstaller` 缺少 linked-root 保护，导致 GitHub/local repo skill 在特殊 provider 目录布局下被错误地重新符号链接。
  - “一直安装中再报错”的主根因，是 Resource Center 没有即时消费安装错误，而是只靠 timeout 清理 pending 状态。
- 已执行行动：
  - 修复安装器 linked-root 落地逻辑。
  - 修复 UI 安装失败即时回传逻辑。
  - 补充并跑通定向回归测试。
- 后续建议：
  - 补一轮更广的 Resource Center 安装入口回归，确认所有入口都遵循同一套 `async throws` 错误链路。

## Round 4（2026-04-14 16:40，多 Agent / 外部 CLI 复核）

### 参与者观点
- `Singer`
  - `SkillInstaller` 的 linked-root 修复方向正确，且测试已经覆盖了用户反馈里的 `scale` 典型路径。
  - 当前实现仍只处理“`defaultSkillsPath` 自身就是符号链接”的场景；如果未来出现父目录级别的间接链接布局，这个保护分支不会触发。
- `Helmholtz`
  - `async throws` 改造确实能解决 Resource Center 主列表里“长时间安装中再报错”的问题。
  - 但 detail sheet 上 workflow / MCP 的安装入口目前仍有 `try? await` 包装，错误可能在这些次级入口被吞掉，不能完全享受新的失败即时回传链路。
- `Gemini CLI`
  - 无 blocking finding。
  - 认可这次修改能对症解决 `scale` 的真实根因。
  - 额外提醒 3 个非阻塞边界：
    - linked-root 解析仍是单层符号链接解析
    - `copyMaterializingSymlinks` 在超大仓库/大资源链接场景下可能带来空间与耗时压力
    - 路径字符串比对对大小写不敏感文件系统仍不算最强健
- `Claude Code`
  - 本轮已尝试参与，但在可接受等待时间内未返回有效审查内容，因此不纳入本轮实质结论。

### 复核结论
- 当前共识：
  - **主修复方向成立，可以解决用户反馈的 `scale` 安装失败问题。**
  - **没有新的 blocking finding 足以推翻当前改动。**
- 新增的边界风险按优先级排序：
  1. Resource Center detail sheet 的 workflow / MCP 安装入口仍可能吞错，需要继续统一错误传播链路。
  2. linked-root 解析目前只覆盖单层符号链接，后续若支持更复杂目录布局，需升级为真实路径解析。
  3. 实体化复制在超大资源场景下可能拉长安装时间，仍可能触发 UI 的 45 秒 timeout 提示。

### 行动建议
- 第一优先：
  - 补 detail sheet 安装入口回归，统一移除 `try? await` 吞错路径。
- 第二优先：
  - 将 linked-root 判断从单层 `destinationOfSymbolicLink()` 提升为更完整的真实路径解析策略。
- 第三优先：
  - 若后续观察到大仓库安装耗时明显，再评估安装进度反馈或 timeout 策略，不在本轮阻塞上线。

## Round 5（2026-04-14 17:05，分歧关闭）

### 新动作
- 已将以下入口统一改为走同一套 `begin*Install(...)` 状态机：
  - workflow detail sheet
  - MCP detail sheet
  - remote skill detail window
- 对应结果：
  - 不再通过 `Task { try? await ... }` 直接吞掉错误。
  - 这些入口现在也会复用相同的 pending / error / timeout 处理逻辑。
- 定向验证再次通过：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/SkillInstallerTests -only-testing:nolonTests/ResourceCatalogGridViewInstallStateTests`

### 最终复核结果
- `Singer`
  - 没有 blocking 分歧；detail 入口统一后，这次 `scale` 安装修复已经在所有相关入口闭环。
- `Helmholtz`
  - 没有 blocking 分歧；主列表、detail sheet、skill detail window 现已统一走 `begin*Install`，错误传播与 pending 清理一致。
- `Gemini CLI`
  - 没有 blocking 分歧；剩余仅为性能、边缘兼容性、长期维护性等非阻塞风险。
- `Claude Code`
  - 最终极简 prompt 返回：没有 blocking 分歧，detail 入口统一后只剩验证和收尾。

### 最终共识
- **所有参与方已经达成一致：这次修改能够解决用户反馈的 `scale` 安装失败与“长时间安装中再报错”问题，不再存在 blocking 分歧。**
- 当前剩余问题全部降级为非阻塞边界：
  1. linked-root 解析仍主要覆盖单层符号链接。
  2. `copyMaterializingSymlinks` 在超大资源仓库下可能带来性能/空间压力。
  3. timeout 策略在极慢安装场景下仍可能显示保守的 retry hint。

## Round 6（2026-04-14 17:36，验证闭环）

### 新动作
- 已将 linked-root 判断继续升级为真实路径解析：
  - 不只判断 `defaultSkillsPath` 自身是否是符号链接。
  - 还会比较 provider root 与 source parent 在 `resolvingSymlinksInPath()` 后的真实路径，覆盖“父目录是 symlink / 多级跳转后落到全局 skills root”的布局。
- 已补充新的 BDD 测试：
  - `testBDD_GivenParentLinkedProviderRoot_WhenInstallLocal_ThenKeepGlobalSkillAsRealDirectory`
- 已再次执行定向验证：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/SkillInstallerTests -only-testing:nolonTests/ResourceCatalogGridViewInstallStateTests`

### 验证结果
- 测试时间：2026-04-14 17:36（Asia/Shanghai）
- 结果：`10` 个测试全部通过，`0` 失败
- 覆盖：
  - `ResourceCatalogGridViewInstallStateTests`：2/2 通过
  - `SkillInstallerTests`：8/8 通过，包含新的“父目录 symlink”保护用例

### 收口结论
- **到这一轮为止，关于 `scale` GitHub skill 安装失败的修复已经完成代码、状态机、边界路径与定向测试四层闭环。**
- **所有已参与讨论的内部 agent 与外部 CLI 结论保持一致：没有剩余 blocking 分歧。**
- 仍保留的事项仅为长期优化议题，不影响本轮问题关闭：
  1. 更复杂大小写/跨挂载点路径归一化策略。
  2. 超大仓库实体化复制的性能与空间观测。
  3. 极慢安装链路下的超时提示体验。
