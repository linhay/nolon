# Main Merge Notes (2026-02-27)

## Scope

- Branch: `codex-version-manager`
- Merge target: `main`
- Ahead of `main`: **280 commits**

## Commit Mix

- `refactor`: 105
- `feat`: 76
- `chore`: 31
- `docs`: 29
- `test`: 19
- `fix`: 14

## High-Impact Change Tracks

1. SDK 下沉与 App/CLI 统一（主要在 `libs/Providers`）
- 资源 list 文本渲染 presenter 下沉到 SDK，并复用到 CLI。
- `RemoteCatalogItem -> RemoteSkill/RemoteWorkflow/RemoteMCP` 映射统一。
- Provider 资源维护、发现、状态汇总、更新策略等逻辑集中到 SDK service。
- CLI 和 App 逐步移除重复解析/拼装逻辑，改为调用 SDK。

2. CLI 体验重构（`skills/workflow/mcp`）
- 命令面统一：`list/search/add/remove/sync`。
- `--show-fixes` 与 verbose 输出结构重写（分块、分状态、修复命令可复制）。
- 帮助文案改为逐参数逐行注释，提升可读性。
- 本地化文案与空态提示统一。

3. 资源中心与仓库管理 UI 重构（App）
- 旧远程浏览器替换为统一“资源中心”（skills/workflows/mcp）。
- 卡片外壳与元信息构建器复用，状态显示统一。
- “添加仓库”流程改为自动化：自动命名、拖拽导入、Git URL 粘贴、upsert 写入。
- 视图布局、间距、可读性与反馈文案多轮优化。

4. Codex 账号与用量链路收口（SDK/CLI/App）
- 账号管理、刷新、runtime/home 切换、状态映射链路统一。
- 费用相关展示移除，仅保留 token 维度。
- 趋势图 + 可排序表格联动，筛选范围覆盖今天/7天/30天/全量。
- 错误态隔离，避免 provider tab 间错误污染。

## Representative Commits

- `9db53f7` feat(codex-usage): unify auth management flow and provider usage UX
- `cede831` refactor(resource-center): replace remote browser with unified resource center
- `db98c45` feat(add-repository): improve drop zone and auto repository setup
- `34203b2` fix(skill-install): restore local git skill install path in app and cli
- `1daceac` feat(codex-usage): add token trend service, cli command, and app chart/table
- `89b409a` refactor(app): remove codex cost UI and keep usage metrics only
- `3d50948` refactor(cli): use sdk resource list text presenter
- `da8c77d` feat(sdk): add resource list presenter and remote catalog mapper
- `1e5b966` feat(sdk): add remote query/count, sync orchestrator, and resource snapshot services
- `4bc7fd6` docs: capture one-shot sdk downsink for remote query and sync orchestration

## Validation Status

- `libs/Providers` 单测（关键子集）已通过：
  - `swift test --package-path libs/Providers --filter NolonResourceKit`
  - `swift test --package-path libs/Providers --filter CodexAuthManager`
- App 编译链路已多轮验证：
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug build`
- `nolonTests` 全量 test action 仍有历史可见性问题（非本分支引入），需在合并前单独治理。

## Merge Risks

1. 变更面广（SDK/API/UI/CLI 同时修改），需要严格按模块回归。
2. `nolonTests` 工程级历史问题会影响“全量绿灯”信号，需额外豁免说明或先修复。
3. 资源中心与仓库流转重构后，需重点回归本地目录/Git/快捷安装三条入口。
4. Codex 登录与用量链路依赖本地运行环境与账号状态，需验证异常场景（无账号、过期、损坏 token）。

## Pre-Merge Checklist

1. 运行 SDK 关键测试（至少 `NolonResourceKit` + `CodexAuthManager`）。
2. 运行 `nolon-app` Debug build。
3. 手工回归：
- 资源中心：skills/workflows/mcp 列表、安装、修复提示。
- 添加仓库：本地拖拽、Git URL、自动命名、重复仓库 upsert。
- Codex 用量：首次启用、导入、登录、token 趋势与表格联动。
4. 明确 `nolonTests` 历史问题处理策略（先修/豁免）。

## Suggested Merge Strategy

1. 先将 `docs-linhay/dev/ops/main-merge-notes-2026-02-27.md` 作为合并说明附件。
2. 若需要降风险，可按域拆分 PR：
- A: SDK 下沉 + CLI 对齐
- B: 资源中心 + 添加仓库 UI
- C: Codex 登录与用量
3. 每个 PR 附带固定回归脚本与截图，避免口头确认。
