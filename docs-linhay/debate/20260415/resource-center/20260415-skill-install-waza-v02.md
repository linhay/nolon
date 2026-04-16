# skill-install-waza

**日期**：20260415
**模式**：合作型
**参与者**：Codex（主持）/ Gemini（福尔摩斯）/ Codex Explorer（Archimedes / Helmholtz / Locke）
**总轮次**：4 / 60
**结束原因**：关键分歧已消除，形成可执行共识

## 辩论背景

用户反馈 `tw93/Waza` 仓库下的 skill 在 Nolon 中安装时会“一直显示安装中，然后报错”。用户要求：

- 必须先读代码，再下结论
- 希望找到根因，而不是只修现场脏数据
- 希望方案是通用方案，而不是只针对 Waza 的特判

本轮在已有 v01 结论基础上，继续补齐三类证据：

1. `NOLON_HOME` / `HOME` 双根分叉是否足以制造跨 root 污染
2. UI timeout 是否只是安装器问题，还是还有 refresh 目标错位
3. 通用修法应当只修安装器，还是同时加入 root 自愈

## 本轮新增代码事实

### 1. 双根分叉是结构性事实，不是偶发

- 论点：全局 skill 根和 provider 默认路径来自两套不同环境变量来源。
  引用：`libs/Providers/Sources/NolonResourceKit/Infrastructure/NolonManager.swift:41`、`libs/Providers/Sources/Providers/Shared/NolonHomeEnvironment.swift:11`、`libs/Providers/Sources/ProviderCatalog/ProviderTemplate.swift:108`、`libs/Providers/Sources/ProviderCatalog/ProviderTemplate.swift:238`
  代码事实：
  - `NolonManager` 通过 `NolonHomeEnvironment` 优先读取 `NOLON_HOME`
  - `ProviderTemplate.defaultSkillsPath` 通过 `currentUserHomeURL()` 读取 `HOME`
  结论：只要某次运行的 `NOLON_HOME` 不等于默认 `HOME/.nolon`，就天然可能出现“当前 global root”和“provider 默认 skills root”不一致。

### 2. 安装内核在 foreign root 下会继续创建 symlink

- 论点：App 安装链路在“provider root resolve 后不等于当前 source root”时，会直接创建 symlink。
  引用：`libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift:223`、`libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift:757`、`libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift:783`
  代码事实：
  - `installLocal` 先把 skill 复制到当前 `nolonManager.skillsPath`
  - 之后 `installSkillContent` 只有在 `resolvedProviderRoot == resolvedSourceRoot` 时才 materialize copy
  - 否则 `.symlink` 分支直接 `createSymbolicLink(to: sourcePath)`
  结论：如果 provider 根路径本身是一个旧 root link，当前实现会继续制造跨 root symlink 污染。

- 论点：CLI 侧存在同构漏洞，不能只修 App。
  引用：`libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillMaintenanceService.swift:230`、`libs/Providers/Sources/NolonCoreCLIKit/NolonSkillsRepositoryService.swift:466`
  代码事实：
  - CLI 的 `installSkill` 最终进入 `ProviderSkillMaintenanceService.installSkillInternal`
  - 该函数与 App `SkillInstaller.installSkillContent` 使用同构的 linked-root / symlink 逻辑
  结论：这不是单一入口 bug，而是共享安装策略层 bug。

### 3. Provider root link 是显式功能，但当前没有安装时自愈

- 论点：provider skills 根链接到 global root 是产品允许的行为，但只在显式操作时维护。
  引用：`libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillsLinkService.swift:42`、`libs/Providers/Sources/NolonResourceKit/Infrastructure/ProviderSkillsLinkService.swift:76`
  代码事实：
  - `ProviderSkillsLinkService` 会把 provider skills 根重链到当前 `nolonManager.skillsFolder`
  - 但它是单独的 preflight/apply 流程，不在安装内核里自动兜底
  结论：一旦用户在不同 `NOLON_HOME` 之间切换，旧 root link 会变 stale；当前安装流程不会自动修正。

### 4. UI 侧确实还有一条 refresh 目标错位链

- 论点：用户在没有固定 `targetProvider` 的资源中心窗口里临时选择 provider 安装后，post-install refresh 仍然使用窗口级 `targetProvider`，而不是刚才实际安装的 provider。
  引用：`nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCenterView.swift:264`、`nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCenterView.swift:271`、`libs/NolonUIFoundation/Sources/NolonUIFoundation/ResourceInstallSelectionViewModel.swift:26`
  代码事实：
  - 卡片安装按钮在 `targetProvider == nil` 时会弹 provider 选择器
  - 用户选中某 provider 后，`onInstall(skill, provider)` 会用这个 provider 真正安装
  - 但随后 `schedulePostInstallRefresh(... fallbackTargetProvider: targetProvider)` 传入的仍是窗口级 `targetProvider`，不是刚才选中的 `provider`
  结论：在“窗口未绑定 provider，用户临时选 provider 安装”的场景里，refresh 目标可能错位到 `nil`，从而不按实际 provider 回写 installed 状态。

### 5. UI timeout 是 installed 集合未回写的结果，不是单纯“扫描慢”

- 论点：UI timeout 的直接触发条件是 pending 结束后 `installedSlugs` 仍不包含当前 slug。
  引用：`nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCatalogGridView.swift:796`、`nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCatalogGridView.swift:816`、`libs/Providers/Sources/NolonResourceKit/Infrastructure/InstalledResourceStatusService.swift:17`
  代码事实：
  - 安装点击后先插入 `pendingSkillInstalls`
  - 45 秒后若 `installedSlugs` 仍不含该 slug，则写入 timeout 错误
  - `installedSlugs` 由 `InstalledResourceStatusService.installedSkillIDs(...)` 决定
  结论：Gemini “主要是扫描慢/卡住 UI” 这条被驳回；真正决定是否 timeout 的是 installed 状态有没有按正确 provider / 正确 root 回写。

## 现场状态复核

- 当前环境 `HOME=/Users/linhey`，`NOLON_HOME` 未设置
- `~/.nolon/providers.json` 中各 vendor provider 的 `defaultSkillsPath` 均落在 `~/.codex/skills` / `~/.gemini/skills` / `~/.copilot/skills` / `~/.config/opencode/skills`
- 现场这些路径都已被 link 到 `~/.nolon/skills`
- 现场异常项：
  - `~/.nolon/skills/learn -> /private/tmp/nolon-home-waza/skills/learn`
  - `~/.nolon/skills/design -> ~/.nolon/skills/design`（自指）
  - `health/hunt/read/think/write` 也已退化为 broken self-link

这说明：

1. Waza 相关现场污染是真实存在的，不是推断
2. 根链接 stale 与 skill entry 污染已经同时存在
3. 仅靠“删掉坏 skill 重新装一次”不足以阻断后续复发

## 共识结论

### 结论 1：根因不是单点，而是两条链叠加

- 主根因：安装内核没有处理 `NOLON_HOME` / `HOME` 双根分叉后的 foreign-root link，继续创建跨 root symlink
- 次根因：Resource Center 在“临时选 provider”场景里，post-install refresh 可能仍按窗口级 `targetProvider` 刷新，导致 installed 状态回写目标错位

### 结论 2：通用方案必须选 C，不是 A-only 或 B-only

- A-only（只修安装器判定）不够：
  - 能减少继续污染
  - 但存量 stale root link 仍不会自愈
- B-only（只修 root 自愈）不够：
  - 不能覆盖所有安装入口与时机
  - CLI / maintenance service 仍可能继续写坏链接
- 最终裁定：**选 C，两者都修**

## 执行口径

### P0

- 在共享安装策略层加入 foreign-root guard
  - App `SkillInstaller.installSkillContent`
  - CLI `ProviderSkillMaintenanceService.installSkillInternal`
- 规则：
  - 保留现有“linked root mirrors current source root => materialize copy”优先级
  - 新增“foreign managed root / stale root link”检测
  - 命中后禁止继续创建跨 root symlink

### P1

- 对启用了 `skillsLinkEnabled` 的 provider 增加 root 自愈
  - 若 provider skills root 当前指向的不是 active global root，则在安装前先重链到当前 root
  - 自愈只对 Nolon 自己声明管理的 skills root 生效，不扩大到任意用户自定义 symlink 目录

### P2

- 修正 Resource Center post-install refresh 目标
  - `ResourceCenterView` 安装成功后，应把“刚才实际安装的 provider”传给 refresh，而不是继续传窗口级 `targetProvider`

### P3

- 补齐回归测试
  - Given stale provider root link + custom `NOLON_HOME`, When install, Then 不产生跨-root symlink
  - Given no fixed window targetProvider, When user selects provider in sheet and install succeeds, Then refresh uses selected provider 而不是 `nil`
  - Given foreign-root polluted entry, When refresh installed status, Then 不会卡在 pending 到 timeout

## 主持人裁定

本轮已达成共识：

- Waza 现场问题不是“单纯一个脏 skill 条目”
- 真正需要修的是“共享安装策略 + root 自愈 + UI refresh 目标”三点闭环
- 其中安装策略和 root 自愈是通用方案主体，UI refresh 是放大器 bug，也必须顺手修掉
