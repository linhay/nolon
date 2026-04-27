# Codex Sessions 原始字段保留与展示执行计划

日期：2026-04-15

关联文档：
- `docs-linhay/spaces/codex-sessions-tab/debate/20260415/codex-sessions/20260415-codex-sessions-raw-fields-v01.md`
- `docs-linhay/spaces/codex-sessions-tab/README.md`
- `docs-linhay/spaces/codex-sessions-tab/plans/2026-04-14-codex-sessions-project-first-exec.md`

## 背景
- `codex-sessions` 第二轮 `project-first` UI/UX 已完成，主表格冻结为：
  - `名称 / id / 时间 / provider / 用量 / 菜单`
- 新 debate 关注点不再是主结构，而是：
  - rollout 原始字段 `forkedFromID / originator / source` 应如何保留与展示
- 最终裁决已冻结：
  - `Forked From` 放在 `ID` 列下方
  - `originator / source` 放在 `Name` 列下方 metadata
  - 不单独新增 `originator / source` 主列
  - menu 保留完整 raw 值，作为低频诊断入口

## 目标
1. scanner -> store -> view model -> UI model 全链路无损保留 `forkedFromID / originator / source`。
2. UI 主表格维持现有 6 列，不新增 debug 型列。
3. `Forked From` 在 `ID` 列下方显示，且支持短值压缩。
4. `originator / source` 在 `Name` 列下方显示为 metadata。
5. menu 中保留完整 raw metadata，便于复制与诊断。

## BDD 场景
1. Given rollout meta 含 `forked_from_id / originator / source`
   When scanner 解析会话
   Then 这些字段被保留，不在 scanner 层丢失。

2. Given store 从 scanner 装配 `CodexSessionRecord`
   When 生成 snapshot
   Then `forkedFromID / originator / source` 仍可在 record 中读取。

3. Given sessions table 渲染单条 row
   When row 含 `forkedFromID`
   Then `ID` 列下方显示 `Forked From` 次级文本。

4. Given sessions table 渲染单条 row
   When row 含 `originator / source`
   Then `Name` 列下方显示 metadata items，而不是新增主列。

5. Given 用户打开单条 row 的 menu
   When row 含 raw metadata
   Then menu 中可查看完整 raw 值，不受单元格压缩影响。

## 实施步骤

### Phase 1：测试先行
1. `CodexSessionScannerTests`
   - 锁定 scanner 不丢 raw metadata。
2. `CodexSessionStoreTests`
   - 锁定 store snapshot 保留 raw metadata。
3. `CodexSessionsTabViewModelTests`
   - 锁定 row 保留 `forkedFromID / originator / source`。
4. `CodexSessionsSectionDataBuilderTests`
   - 锁定：
     - `Forked From` -> `idSecondaryText`
     - `originator / source` -> `nameMetadataItems`
     - menu -> `menuMetadataItems`

### Phase 2：数据链路扩展
1. `CodexSessionScanner.SessionMeta` 新增：
   - `forkedFromID`
   - `originator`
   - `source`
2. `CodexSessionStore.CodexSessionRecord` 新增同名字段。
3. `CodexSessionsTabViewModel.SessionRow` 增加同名字段并透传。

### Phase 3：UI 数据模型与表格展示
1. `CodexSessionsRowData` 新增：
   - `nameMetadataItems`
   - `idSecondaryText`
   - `menuMetadataItems`
2. `CodexSessionsSectionDataBuilder`
   - `Forked From` 映射到 `idSecondaryText`
   - `originator / source` 映射到 `nameMetadataItems`
   - 完整 raw 值映射到 `menuMetadataItems`
3. `UnifiedCodexSessionViews`
   - `Name` 列渲染 metadata pills
   - `ID` 列渲染 secondary text
   - menu/context menu 渲染 metadata items

### Phase 4：本地化与回归
1. 补 `Localizable.xcstrings`：
   - `codex.sessions.metadata.forked_from`
   - `codex.sessions.metadata.originator`
   - `codex.sessions.metadata.source`
2. 定向运行 package + app 测试。
3. 验证 snapshot 目标未被编译或展示变更打坏。

## 风险与缓解
1. 风险：直接新增主列会破坏高频扫描效率。
   - 缓解：坚持 6 列不变，只在单元格内扩展次级信息。
2. 风险：raw metadata 过长导致表格噪音。
   - 缓解：单元格只显示 compact 值，完整值留在 menu。
3. 风险：Swift 测试目标在长表达式下触发 type-check 超时。
   - 缓解：测试中避免过重 keypath shorthand 和超长 initializer 闭包表达式。

## 完成定义（DoD）
1. `forkedFromID / originator / source` 全链路保留。
2. `Forked From` 显示在 `ID` 列下方。
3. `originator / source` 显示在 `Name` 列下方 metadata。
4. menu 可查看完整 raw metadata。
5. 定向 package 与 app 测试通过。

## 执行结果（2026-04-15 01:24 CST）
- 状态：已完成。
- 实际落地：
  - scanner / store / view model / UI row model 已全链路保留 `forkedFromID / originator / source`
  - `Forked From` 已落到 `ID` 列下方
  - `originator / source` 已落到 `Name` 列下方 metadata
  - menu 已补完整 raw metadata 展示
  - `Localizable.xcstrings` 已补三条 metadata 文案
- 验证回执：
  - `xcodebuild test -workspace libs/Providers/.swiftpm/xcode/package.xcworkspace -scheme Providers-Package -destination 'platform=macOS' -only-testing:ProvidersTests/CodexSessionScannerTests -only-testing:ProvidersTests/CodexSessionStoreTests`
  - 结果：`2` 个 package 级用例通过，`0` 失败
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -skipPackageUpdates -clonedSourcePackagesDirPath /Users/linhey/Library/Developer/Xcode/DerivedData/nolon-daifteoyynegwuevitolzuidfhnx/SourcePackages -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests -only-testing:nolonTests/CodexSessionsTabViewModelTests`
  - 结果：`10` 个 app 级用例通过，`0` 失败
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -skipPackageUpdates -clonedSourcePackagesDirPath /Users/linhey/Library/Developer/Xcode/DerivedData/nolon-daifteoyynegwuevitolzuidfhnx/SourcePackages -only-testing:nolonTests/CodexSessionsCardSnapshotTests`
  - 结果：`3` 个快照用例通过，`0` 失败
