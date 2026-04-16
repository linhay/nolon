# Skill 安装双根污染与状态回写修复设计（2026-04-15）

## 背景

本轮围绕 `tw93/Waza` 仓库下 skill 无法正常安装的问题进行了多轮代码取证与 debate，当前已确认：

1. 问题不是 Git 仓库同步失败，也不是 repo 名 `Waza` 被错误当作 slug 安装。
2. 问题也不是单纯“扫描慢”或“UI 卡住”。
3. 真正的根因是安装策略层与安装后状态回写链路同时存在缺口。

关联辩论文档：

- `docs-linhay/debate/20260415/resource-center/20260415-skill-install-waza-v02.md`

## 现象定义

用户可观察到的现象有两类：

1. 在 Resource Center 安装 `tw93/Waza` 下的 skill 时，卡片一直显示“安装中”。
2. 约 45 秒后，UI 进入 timeout 错误态。

现场还存在存量污染：

1. `~/.nolon/skills/learn -> /private/tmp/nolon-home-waza/skills/learn`
2. `design/health/hunt/read/think/write` 已退化为 broken self-link

这说明当前问题不是一次性偶发失败，而是已经把错误状态写入了全局 skill 根。

## 当前代码事实

### 1. global root 与 provider root 天然可能分叉

1. [`NolonManager.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/NolonManager.swift#L41) 通过 `NOLON_HOME` 决定 active global root。
2. [`NolonHomeEnvironment.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Shared/NolonHomeEnvironment.swift#L7) 在未设置时回落到 `HOME/.nolon`。
3. [`ProviderTemplate.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderCatalog/ProviderTemplate.swift#L108) 与 [`ProviderTemplate.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderCatalog/ProviderTemplate.swift#L238) 通过 `HOME` 生成默认 provider 路径。

结论：

- `NOLON_HOME` 与 `HOME` 不是同一个配置源。
- 只要用户曾在临时环境下运行过 Nolon / CLI，就可能留下“当前 global root”和“provider skills root”不一致的状态。

### 2. 安装策略层会继续制造 cross-root symlink

1. [`SkillInstaller.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift#L223) 的 `installLocal` 会先把 skill 写入当前 `nolonManager.skillsPath`。
2. [`SkillInstaller.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift#L757) 只有在 `provider root resolve 后 == source root resolve 后` 时才走 materialize copy。
3. [`SkillInstaller.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift#L783) 否则 `.symlink` 分支直接创建 symlink。
4. [`ProviderSkillMaintenanceService.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillMaintenanceService.swift#L230) 到 [`ProviderSkillMaintenanceService.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillMaintenanceService.swift#L276) 里存在同构逻辑。

结论：

- App 与 CLI 都会在 foreign-root 场景下继续创建 cross-root symlink。
- 这是共享安装策略层缺陷，不是单个入口 bug。

### 3. Nolon 已支持 provider root link，但当前没有安装时自愈

1. [`ProviderSkillsLinkService.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillsLinkService.swift#L42) 会检查 provider skills root 是否已经指向当前 global root。
2. [`ProviderSkillsLinkService.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillsLinkService.swift#L76) 可以显式把 provider skills root 重链到当前 global root。

结论：

- 产品语义允许“provider skills root 直接 link 到 `~/.nolon/skills`”。
- 但该能力只存在于显式设置流程，不在安装路径中自动兜底。
- 这会导致 stale provider root link 长期存活。

### 4. UI timeout 的直接原因是 installed 状态没有回写

1. [`InstalledResourceStatusService.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/InstalledResourceStatusService.swift#L17) 的已安装集合来自 `scanProvider`。
2. [`SkillInstaller.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift#L513) 到 [`SkillInstaller.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift#L528) 只把“指向当前 global root”的项判为 `.installed`。
3. [`ResourceCatalogGridView.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCatalogGridView.swift#L796) 到 [`ResourceCatalogGridView.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCatalogGridView.swift#L829) 在 45 秒后检查 `installedSlugs` 是否已包含当前 slug。

结论：

- timeout 不是底层安装调用直接抛错。
- timeout 是“安装完了，但 installed 状态没有按预期回写”的 UI 后果。

### 5. Resource Center 还存在 refresh 目标错位

1. [`ResourceInstallSelectionViewModel.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUIFoundation/Sources/NolonUIFoundation/ResourceInstallSelectionViewModel.swift#L26) 表明当窗口未绑定固定 provider 时，安装会先弹 provider 选择器。
2. [`ResourceCenterView.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCenterView.swift#L264) 安装时使用的是用户刚选择的 provider。
3. [`ResourceCenterView.swift`](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCenterView.swift#L271) 但 post-install refresh 传入的仍是窗口级 `targetProvider`。

结论：

- 当窗口级 `targetProvider == nil` 时，安装后 refresh 仍可能按 `nil` 刷。
- 这会让“刚才成功安装到某 provider”与“随后 installed 状态刷新”脱节。

## 根因裁定

### 主根因

共享安装策略层没有处理 foreign-root / stale-root 场景，继续创建 cross-root symlink，污染全局 skill 根。

### 次根因

Resource Center 在“临时选 provider 安装”的场景下，post-install refresh 目标错误，放大了 installed 状态不回写问题。

### 非根因

以下方向已排除：

1. `Waza` repo 名被当作 skill slug。
2. Git 同步失败。
3. `tw93/Waza` 仓库目录结构自身异常。
4. 单纯因为扫描耗时长而 timeout。

## 真实前台验证补充（2026-04-15）

### 前台结论

在真实用户环境的前台 app 中，`tw93/Waza` 已完成安装验证：

1. Resource Center 能正确识别仓库内容：
   - `技能 8`
   - `工作流 0`
   - `MCP 0`
   - `代理说明 1`
2. 搜索 `learn` 后，卡片可见且可点击安装。
3. 点击安装后，`Claude Code` 目标路径成功落盘：
   - `~/.claude/skills/learn -> ~/.nolon/skills/learn`
4. 卡片状态已从 pending 收敛到 `Installed`。

结论：

- 本轮通用修复在真实前台用户环境下已验证通过。
- “一直安装中”不是修复后仍然存在的真实前台问题。

### 验证环境约束

本轮还确认了一个容易误导后续排查的验证约束：

1. `xcodebuild test` 启动的 `nolonUITests.xctrunner` 会重定向 `HOME` / `CFFIXED_USER_HOME` 到 XCTest 容器。
2. Resource Center 在该容器里看到的不是用户真实 `~/.nolon/repositories` 与 `~/.nolon/skills`。
3. 因此 UI test 中出现的：
   - `技能 0`
   - `Git 操作失败：仓库尚未克隆`
   - 安装卡住或 timeout
   不能直接作为真实用户环境中的安装失败证据。

结论：

- 后续凡是验证 GitHub repo skill 安装，必须优先使用真实前台 app 或显式注入真实 `HOME` / `NOLON_HOME` 的独立运行环境。
- XCTest UI runner 结果只能用于验证 UI 流程本身，不能直接裁定真实 repo/skill 安装链路是否回归。

## 设计目标

1. 阻断新的 cross-root symlink 污染继续产生。
2. 让已启用 Nolon root link 管理的 provider 在安装路径上自动收敛到当前 active global root。
3. 让安装后的 installed 状态按“实际安装的 provider”刷新。
4. 保持现有“linked root mirrors current source root => materialize copy”行为不回归。
5. 覆盖 App 与 CLI 两条安装链路。

## 方案裁定

### 方案 A：只修安装策略层

优点：

1. 能阻断继续写坏 symlink。

缺点：

1. 不能修复已经 stale 的 provider root link。
2. 现场存量污染仍会长期影响 installed 判定。

结论：

- 不足。

### 方案 B：只做 root 自愈

优点：

1. 能把一部分 stale root 收敛回来。

缺点：

1. 安装器和 maintenance service 仍会继续制造新污染。
2. 不能覆盖所有安装入口与时机。

结论：

- 不足。

### 方案 C：双修

内容：

1. 安装策略层增加 foreign-root guard。
2. 对 `skillsLinkEnabled == true` 的 provider 增加 stale root 自愈。
3. 修复 Resource Center refresh 目标。

结论：

- 这是唯一同时具备“预防 + 自愈 + 状态回写收敛”的通用方案。

## 实施设计

### 一、共享安装判定下沉

目标：

1. App `SkillInstaller`
2. CLI `ProviderSkillMaintenanceService`

采用同一套判定逻辑：

1. 先保留已有的 linked-root mirror 分支。
2. 再判断 provider root 是否属于 Nolon 管理 root，但指向了非当前 active global root。
3. 若命中：
   - 对可自愈场景，先重链 root 再继续
   - 对不可自愈场景，降级为 materialize copy，禁止创建 cross-root symlink

约束：

1. 不能把所有 symlink provider 都粗暴降级为 copy。
2. 只能对“Nolon 自己声明管理的 skills root”应用自愈或保护。

### 二、root 自愈边界

仅对以下场景启用：

1. `provider.skillsLinkEnabled == true`
2. provider root 当前是 symlink
3. provider root 指向的是某个旧 global root，而不是当前 `nolonManager.skillsFolder`

不处理以下场景：

1. 用户自己手动配置的任意 symlink provider 目录
2. 明确不启用 `skillsLinkEnabled` 的自定义 project provider

原因：

1. 这些路径不一定受 Nolon 管理
2. 不应替用户擅自改写任意自定义目录结构

### 三、UI refresh 修正

Resource Center 安装成功后，`schedulePostInstallRefresh` 应传入：

1. 当前实际安装的 provider

而不是：

1. 窗口级 `targetProvider`

这样可以保证：

1. 固定 provider 窗口继续按固定 provider 刷
2. 临时选 provider 安装场景按真实 provider 刷

### 四、状态判定一致性

在 installed 判定层同步收紧 canonical path 规则：

1. provider root link 到当前 global root 时，仍视为 `.installed`
2. skill symlink 指向当前 global root 时，视为 `.installed`
3. foreign-root skill entry 不应继续被视为正常 installed

说明：

1. 状态层不是根修复入口
2. 但状态层必须与新的安装策略保持一致，否则会出现“装完了但判不成 installed”

## BDD 场景

1. `Given provider skills root 是 stale global root link when 安装 skill then 不生成 cross-root symlink`
2. `Given provider skills root 与当前 source root 完全镜像 when 安装 skill then 继续 materialize copy 而不是回退成普通 symlink`
3. `Given skillsLinkEnabled provider 命中过期 root link when 安装 skill then 先自愈到当前 global root 再完成安装`
4. `Given Resource Center 窗口没有固定 targetProvider when 用户在安装弹窗中选择 provider then post-install refresh 使用用户刚选择的 provider`
5. `Given 安装完成且状态刷新正常 when pending 到期前检查 then 卡片不进入 timeout`

## 推荐代码落点

1. `libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift`
2. `libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillMaintenanceService.swift`
3. `libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillsLinkService.swift`
4. `libs/Providers/Sources/NolonResourceKit/Infrastructure/InstalledResourceStatusService.swift`
5. `nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCenterView.swift`
6. `nolonTests/SkillInstallerTests.swift`
7. `libs/Providers/Tests/ProvidersTests/NolonResourceKitTests.swift`
8. `nolonTests/ResourceCenterViewModelTests.swift`

## 非目标

1. 本文档不主张对所有 provider symlink 路径做激进自愈。
2. 本文档不在本轮处理 skill 内容层面的元数据或 frontmatter 问题。
3. 本文档不尝试一次性清理用户机器上的全部历史坏 skill；存量清理仅覆盖本轮能安全识别的 managed stale root 场景。
