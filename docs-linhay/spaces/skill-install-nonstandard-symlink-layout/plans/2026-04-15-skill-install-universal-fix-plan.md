# Skill 安装通用修复计划

日期：2026-04-15

## 执行状态

状态：已完成

实际落地结果：

1. 共享安装策略已收敛为统一规则：
   - 只要 provider skills root 经过 symlink 解链，安装链路就不再继续写 nested / cross-root symlink，而是直接 materialize 到解链后的真实 root。
   - 对 `skillsLinkEnabled == true` 且指向旧 Nolon managed root 的 provider，会在安装前自动重链到当前 active global root。
   - provider skills 路径只要通过祖先目录 symlink 最终解析到 active global root，扫描链路也统一按 `installed` 识别，不再误判为 `orphaned`。
2. App 与 CLI 两条链路已同时落地：
   - `SkillInstaller` 已接入 shared root resolver 与 managed root 自愈。
   - `ProviderSkillMaintenanceService` 已接入同构逻辑，linked-root / ancestor-linked-root / stale-root 均走同一套 root 解析规则。
3. Resource Center 的 post-install refresh 目标已修正：
   - 安装弹窗动态选中的 provider 会优先作为 refresh 目标。
   - `globalSkills` 视图仍保持 provider-neutral 行为。
4. 运行时卡在“安装中”的直接根因已确认并修复：
   - 并非安装失败，而是安装成功后 `installedSlugs` 刷新依赖的 provider 扫描把“祖先 symlink 映射到全局 root”的技能误判为 `orphaned`，导致 UI 一直等不到 installed 状态回写。

新增/更新测试：

1. `nolonTests/SkillInstallerTests.swift`
   - `GivenManagedStaleProviderRoot_WhenInstallLocal_ThenHealLinkToCurrentGlobalRoot`
   - `GivenParentLinkedProviderRoot_WhenScanningInstalledSkill_ThenMarkInstalled`
2. `nolonTests/ResourceCenterViewModelTests.swift`
   - `GivenProviderSelectedInInstallSheet_WhenResolvePostInstallRefreshTarget_ThenUseSelectedProvider`
   - `GivenGlobalSkillsRepository_WhenResolvePostInstallRefreshTarget_ThenIgnoreInstalledProvider`
3. `libs/Providers/Tests/ProvidersTests/NolonResourceKitTests.swift`
   - `ProviderSkillMaintenanceService marks skills as installed when provider skills root resolves to global through ancestor symlink`
   - `ProviderSkillMaintenanceService heals stale managed provider root before install`
   - 既有 `installs copies into linked global skills root` 回归继续保持通过

实际验证：

1. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/SkillInstallerTests -only-testing:nolonTests/ResourceCenterViewModelTests`
   - 结果：`16` 个测试通过，`0` 失败
2. `xcodebuild test -workspace libs/Providers/.swiftpm/xcode/package.xcworkspace -scheme Providers-Package -destination 'platform=macOS' -only-testing:ProvidersTests/NolonResourceKitTests`
   - 结果：`73` 个测试通过，`0` 失败
3. 真实前台 smoke：
   - 使用真实 app 进程打开 Resource Center，选中 `Waza`，搜索 `learn`
   - 前台可见仓库统计：`技能 8 / 工作流 0 / MCP 0 / 代理说明 1`
   - 点击安装后成功落盘：`~/.claude/skills/learn -> ~/.nolon/skills/learn`
   - 卡片状态已进入 `Installed`

说明：

1. 本轮已经补做真实前台 live smoke / foreground 手点验证，并确认通过。
2. 当前已满足“测试先行 + 双链路修复 + 真实前台验收 + 文档回写”的本计划 DoD。
3. 需要特别区分：`xcodebuild test` 下的 `nolonUITests.xctrunner` 会把 `HOME` 重定向到 XCTest 容器；该环境里看到的“仓库未克隆 / 技能 0”是假失败，不代表真实用户环境回归。

## 背景

本轮已确认 `tw93/Waza` 安装问题背后不是单点 bug，而是两条链叠加：

1. 共享安装策略层会在 foreign-root 场景继续制造 cross-root symlink 污染。
2. Resource Center 在“临时选 provider 安装”场景下会用错误的 provider 做 post-install refresh。

依据文档：

- `docs-linhay/dev/skill-install-universal-fix-design-2026-04-15.md`
- `docs-linhay/spaces/skill-install-nonstandard-symlink-layout/debate/20260415/resource-center/20260415-skill-install-waza-v02.md`

## 目标

1. 阻断新的 cross-root symlink 污染。
2. 让 Nolon 管理的 stale provider skills root 在安装时自动收敛。
3. 修正 Resource Center 安装后 installed 状态回写目标。
4. 补齐 App 与 CLI 两条链路的回归测试。

## BDD 场景

1. `Given stale provider root link + current active global root when 安装 skill then 不产生 cross-root symlink`
2. `Given linked root mirrors current source root when 安装 skill then 仍保持 materialize copy`
3. `Given skillsLinkEnabled provider 指向旧 global root when 安装 skill then provider root 被自愈到当前 global root`
4. `Given Resource Center 未固定 targetProvider when 用户在安装弹窗里选了 provider then refresh 使用该 provider`
5. `Given 安装成功且 installed 状态正确回写 when timeout 检查发生 then 卡片不进入 timeout`

## Phase 0：测试基线

目标：

1. 先补失败测试，锁定当前缺口。

执行项：

1. 在 [`SkillInstallerTests.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/SkillInstallerTests.swift) 新增 foreign-root mismatch 用例。
2. 在 [`NolonResourceKitTests.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Tests/ProvidersTests/NolonResourceKitTests.swift) 为 `ProviderSkillMaintenanceService` 补 CLI 侧同构用例。
3. 在 app 侧为 Resource Center 补“动态选 provider 后 refresh 使用实际 provider”的测试。
4. 明确现有 linked-root copy 测试仍必须保持通过。

完成标志：

1. 当前 bug 能被测试稳定复现。
2. 现有正确行为有回归保护。

## Phase 1：共享安装策略防污染

目标：

1. App 与 CLI 两条链路共用同一套 foreign-root guard。

执行项：

1. 从 `SkillInstaller` 与 `ProviderSkillMaintenanceService` 中抽出共享判定逻辑。
2. 保留现有 mirror-root materialize copy 分支优先级。
3. 新增 foreign-root 保护：
   - 命中 managed stale root 时优先自愈
   - 否则禁止继续创建 cross-root symlink
4. 复查 `migrate` 等旁路逻辑，避免重新混用 `NolonManager.shared` 与注入实例。

完成标志：

1. 安装路径不再写出新的 cross-root symlink。
2. App 与 CLI 表现一致。

## Phase 2：managed root 自愈

目标：

1. 仅对 Nolon 管理的 root link 做安全自愈。

执行项：

1. 以 `skillsLinkEnabled == true` 作为受管前提。
2. 若 provider skills root 当前为 symlink 且目标不是 active global root：
   - 在安装前重链到当前 global root
3. 不改写普通自定义 symlink provider 路径。

完成标志：

1. stale managed root 会在安装路径中自动收敛。
2. 不误伤用户自定义路径。

## Phase 3：UI refresh 修正

目标：

1. 安装成功后按真实 provider 回写 installed 状态。

执行项：

1. 调整 [`ResourceCenterView.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCenterView.swift) 的 `schedulePostInstallRefresh` 调用参数。
2. 固定 provider 场景继续走固定 provider。
3. 动态选择 provider 场景改为使用刚刚选中的 provider。

完成标志：

1. 安装后 `installedSlugs` 能按实际 provider 正常回写。
2. 卡片不会因为 refresh 目标错位而无故 pending 到 timeout。

## Phase 4：存量污染校验与回归

目标：

1. 验证修复后对现场脏数据和未来安装都具备收敛能力。

执行项：

1. 在测试环境模拟：
   - `/tmp/nolon-home-waza/skills/...`
   - `~/.codex/skills -> 旧 .nolon/skills`
   - broken skill entry
2. 校验安装后：
   - 不会继续写坏
   - installed 状态能正确识别
3. 必要时增加定向日志，输出：
   - active global root
   - provider root
   - resolved provider root
   - 采用 copy / symlink / heal 的最终分支

完成标志：

1. 新旧场景都可解释、可验证。
2. 没有新的行为回归。

## 推荐修改顺序

1. 先补测试
2. 再做共享安装 guard
3. 再加 managed root 自愈
4. 再修 Resource Center refresh
5. 最后统一跑回归

## 测试门禁

### 先补失败测试

1. `Given foreign provider root when install then installer does not create cross-root symlink`
2. `Given foreign provider root when maintenance service installs then service does not create cross-root symlink`
3. `Given selected provider in install sheet when refresh runs then selected provider is used`

### 定向验证

1. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS'`
   - 至少覆盖 `SkillInstallerTests`、`ResourceCenterViewModelTests`、相关 app 侧回归测试
2. `xcodebuild test -workspace libs/Providers/.swiftpm/xcode/package.xcworkspace -scheme Providers-Package -destination 'platform=macOS'`
   - 至少覆盖 `NolonResourceKitTests`

## 风险与防线

### 风险 1：把所有 symlink provider 都误判为 foreign-root

防线：

1. 只对 Nolon 管理的 root link 做自愈。
2. mirror-root copy 分支优先级保持不变。

### 风险 2：只修 App，CLI 继续写坏

防线：

1. 共享判定逻辑必须同时落到 `SkillInstaller` 与 `ProviderSkillMaintenanceService`。

### 风险 3：只修安装层，UI 仍 timeout

防线：

1. Resource Center refresh 目标修正必须与安装层修复同轮交付。

## 非目标

1. 本计划不包含长期驻留式 foreground 手工回归。
2. 本计划不处理与 Waza 无关的 skill 元数据整理。
3. 本计划不试图修正 XCTest runner 的容器化 `HOME` 行为；该问题属于验证环境约束，而非本次安装链路缺陷。
