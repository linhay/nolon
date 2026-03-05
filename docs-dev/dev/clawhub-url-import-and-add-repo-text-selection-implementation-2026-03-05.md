# Clawhub 链接导入与添加仓库文本可选中：实现说明（2026-03-05）

关联需求：`docs-dev/features/clawhub-url-import-and-add-repo-text-selection-2026-03-05.md`

## 设计决策
1. 统一导入意图解析（避免“按页面分别猜 URL”）：
   - `RepositoryDraftService` 新增 `parseImportIntent(from:) -> ImportedResourceIntent`。
   - 统一产出三类意图：`.clawhubSkill` / `.gitRepository` / `.unknown`。
   - 兼容 host：`clawhub.ai` / `clawdhub.com`（含 `www`），支持无 scheme 输入与 `slug.git` 误后缀。

2. 资源中心入口分流：
   - `ResourceCenterView.handlePendingImportURLIfNeeded()` 改为按 `parseImportIntent` 分流。
   - `.clawhubSkill`：切换 Clawdhub 仓库 + `skills` tab + 预填 `slug` 搜索并消费 URL。
   - `.gitRepository`：不拦截，交由侧栏 AddRepository 既有流程。
   - `.unknown`：展示可复制错误提示并消费 URL。

3. 侧栏弹窗分流：
   - `RemoteRepositorySidebarView.shouldOpenAddRepositorySheet` 仅对 `.gitRepository` 返回 true。
   - 结果：Clawhub 链接不再误弹 Git 导入弹窗。

4. AddRepositorySheet 分流：
   - `AddRepositoryViewModel` 新增 `applyPendingImportURL(_:)`。
   - 仅 `.gitRepository` 预填 `newGitURL/newRepoName`，其它链接直接跳过。
   - 结果：即使 pending URL 进入 AddRepository 生命周期，也不会把 Clawhub 当 Git。

5. 文本可选中：
   - `AddRepositorySheet` 与资源中心错误提示文案使用 `.textSelection(.enabled)`，支持复制排障信息。

## 测试策略
- `libs/Providers/Tests/ProvidersTests/NolonResourceKitTests.swift`：
  - `RepositoryDraftService extracts Clawhub skill query from marketplace URL`
  - `RepositoryDraftService parses import intent for Clawhub and Git URLs`
- `nolonTests/AddRepositoryViewModelTests.swift`：
  - `testInit_WithPendingGitURL_PrefillsGitFields`
  - `testInit_WithPendingClawhubURL_DoesNotPrefillGitFields`

## 验证结果
- 通过：
  - `swift test --package-path libs/Providers --filter repositoryDraftServiceParsesImportIntent`
  - `./build.sh`
- 阻塞（与本次改动无关）：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-app -destination 'platform=macOS' -only-testing:nolonTests/AddRepositoryViewModelTests`
  - 失败原因：`nolonTests/CodexUsageTabPresentationTests.swift` 现存编译错误（`UsageIdentity()` 构造调用不匹配）。
