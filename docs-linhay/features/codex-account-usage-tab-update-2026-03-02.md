# Codex 账号与用量 Tab 命名与操作区更新（2026-03-02）

## 目标
- 将 Codex 相关 Provider 的 `用量` Tab 统一命名为 `账号与用量`。
- 在 Codex 用量页顶部按 active 卡类型提供主操作入口。
- 在 Codex 用量页的 `actionsMenu` 中补充配置型账号管理与列表显示选项。
- 支持将 `ChatGPT`、`官方 API key`、`Relay` 三类账号统一投影为卡片。

## 范围
- 包含：`codex`、`codexXcode` 两类 Provider 的 Tab 文案、用量页头部操作区、`actionsMenu` 分组/排序、配置型账号卡片新增/编辑。
- 不包含：非 Codex Provider 的用量页交互改造、完整的 Relay CLI 管理命令。

## 交互与行为规则
1. Tab 文案规则：
   - `codex`/`codexXcode`：显示 `账号与用量`。
   - 其他 Provider：保持 `用量`（`tab.usage`）不变。
2. Codex 用量页头部按钮按当前 active 卡类型分流：
   - `chatgptAccount`：`刷新 | 登录 | 导入`
   - `officialAPIKey` / `relayProfile`：`刷新 | 编辑 | 验证`
3. `刷新`语义为“全部刷新”，触发当前 Codex 多账号的全量刷新链路（沿用现有 `load()` 内并行刷新逻辑）。
4. 非 Codex Provider 保持原有登录入口与菜单交互，不受本次变更影响。
5. `actionsMenu` 在 Codex 页面新增：
   - 分组：`无分组`、`按套餐/提供商分组`
   - 排序：`按剩余额度`、`按到期时间`、`按名称`
   - 若存在可用 quota window，则在同一排序菜单内追加具体项：
     - `按 1h 剩余比例`
     - `按 24h 剩余比例`
     - 其他可识别窗口同理
   - 不再提供单独的 `额度窗口` 和 `排序方向` 二级菜单
   - 再次点击当前排序项时切换方向；切换到其他排序项时，旧排序项方向状态重置为默认值
   - 配置型入口：`新增 API Key`、`新增 Relay`
6. 分组键规则：
   - ChatGPT 卡：按 `plan`
   - 官方 API key 卡：固定归组 `OpenAI`
   - Relay 卡：优先 `model_provider`，再回退 `base_url.host`
7. 配置型卡片右键菜单支持 `编辑`、`Validate`，不显示 `Re-login`。
8. 分组 section 支持点击标题折叠/展开，折叠状态仅保存在当前页面内存。
9. Codex 排序语义固定为：
   - `按剩余额度`：按 `credits.remaining`，默认降序
   - `按到期时间`：按最早可用 `resetsAt`，默认升序
   - `按名称`：按显示名称，默认升序
   - `按 Xh/Xd 剩余比例`：按对应 quota window 的 `remainingPercent`，默认降序
   - 未选中的排序项不显示方向箭头
   - 切换到其他排序项后，之前排序项的方向状态不保留
   - 缺少当前排序值的卡片排在有值卡片之后
10. `新增 API Key / 编辑配置` 弹框采用简化直出表单：
   - 顶部继续使用标题 + 副标题说明当前模式
   - 关闭按钮使用统一的右上角浮动关闭组件
   - `新增 API Key` 表单字段固定为：`model_provider`、`API Key`、`Base URL`
   - `model_provider` 选填，默认值为 `nolon`
   - `API Key` 为唯一必填项
   - `Base URL` 选填，直接显示，不放进高级折叠区
   - 移除 `HTTP Usage Query`、`Credentials Override`、`Mapping` 与 `Test Request`
   - 三个字段都直接显示，不使用 `Advanced` / `DisclosureGroup`
   - 底部只保留 `Validate` 与主按钮；主按钮文案按模式切换为 `Create` / `Save`
   - 从配置型账号卡片菜单点击 `编辑` 时，必须打开同一套 `CodexConfigEditorSheet`，不能直接打开临时 `auth.json` 文件
11. Codex 卡片支持批量选择模式：
   - 仅在 Codex 页面生效
   - 进入批量模式后，点击卡片改为勾选/取消勾选，不再触发激活
   - 批量模式退出后清空当前选择
12. Codex 支持 ZIP 批量导出：
   - 仅导出当前选中的账号卡
   - 导出内容为对应 `~/.nolon/codex/auth/*.json`
   - 打包为单个 `.zip`
13. Codex 支持 ZIP 批量导入：
   - 允许在现有导入入口中选择 `.zip`
   - ZIP 解压后仅处理其中的 `.json` auth 文件
   - 继续复用现有 auth 校验与导入逻辑
14. ZIP 导入导出不修改 active registry：
   - 不导出 `active-accounts.json` / `active-fingerprints.json`
   - 导入后只新增卡片，不自动激活任何账号
15. Codex 导入改为独立 modal：
   - 点击 `导入` 先打开导入 modal，而不是直接弹系统文件选择器
   - modal 内支持拖拽 `.json` / `.zip`
   - 也支持点击按钮继续调用系统文件选择器
16. 文件进入导入 modal 后，先在下方展示候选账号列表：
   - 候选项显示名称、邮箱、来源文件、校验状态
   - 候选项支持勾选/取消勾选
   - 校验失败项显示原因，默认不可选
17. 导入 modal 会自动测试所有合法候选项的连接：
   - 复用现有 Codex 用量链路测试联通性
   - 测试失败项仍允许导入，但用户可手动取消勾选
   - 测试状态与摘要显示在候选项行内
18. 点击 `导入选中` 时，仅导入当前勾选且校验合法的候选项。
19. 关闭导入 modal 后，本次导入草稿、候选列表和测试状态全部清空。
20. 导入候选列表按“导入来源”分组：
   - 单个 `.json` 文件单独成组
   - 同一个 `.zip` 内解压出的多个账号归为同一组
   - 同一次粘贴生成的候选项也作为单独来源组展示
21. 导入候选支持整组选择和全选：
   - 每个来源组支持 `整组选中 / 取消整组`
   - 顶部工具栏继续支持全局 `全选 / 取消全选`
   - 以上选择动作都只作用于校验合法的候选项
22. 导入 modal 的视觉优先级收敛为：
   - Drop zone 里的 `选择文件` 为主按钮，`粘贴` 为次按钮
   - 底部主按钮显示当前选中数量，如 `导入 3 个账号`
   - 校验/联通测试进行中时，在底部操作区显示全局 `ProgressView` 状态
   - 全局错误使用 banner 容器展示，而不是轻量 caption
23. Codex 账号卡片支持复制 auth JSON：
   - 卡片菜单新增 `Copy Auth JSON`
   - 复制内容为当前账号 auth 文件原文
24. 导入 modal 支持从剪贴板粘贴添加：
   - 支持直接粘贴 auth JSON
   - 粘贴后先进入候选列表，不会直接导入
25. 导入 modal 支持解析 Codex 登录成功回调 URL：
   - 支持 `http://localhost:<port>/success?...`
   - 也兼容 `http://localhost:<port>/auth/callback?...`
   - 允许只有 `id_token` 的恢复导入场景
   - 若存在 `access_token` / `refresh_token` 则一并解析
   - 会先转换成兼容的 auth JSON，再进入现有校验与测试链路
26. Codex 登录只走 app-server 登录链路：
   - 不再 fallback 到 direct CLI OAuth
   - app-server 登录失败时直接报错
   - 避免 direct CLI 按 upstream 默认行为自行拉起浏览器
27. Codex 登录 URL 弹窗只保留单一关闭语义：
   - 顶部按钮直接使用 `取消登录`
   - 不再同时提供语义重复的 `Close` 与 `取消登录`

## BDD 验收
1. Given 当前 Provider 为 Codex，When 查看侧栏 Tab，Then `用量`显示为`账号与用量`。
2. Given 当前 Provider 为 CodexXcode，When 查看侧栏 Tab，Then `用量`显示为`账号与用量`。
3. Given 当前 Provider 为 Codex 且 active 卡是 ChatGPT，When 进入用量页头部，Then 按钮为 `刷新 | 登录 | 导入`。
4. Given 当前 Provider 为 Codex 且 active 卡是配置型卡片，When 进入用量页头部，Then 按钮仍保留 `刷新 | 登录 | 导入`，并额外提供 `编辑 | 验证`。
5. Given 当前 Provider 为非 Codex，When 查看用量页与 Tab，Then 文案与交互保持现状。
6. Given Codex 页面存在官方 API key 或 Relay 卡，When 打开右上角菜单，Then 可以新增配置型卡片并切换分组/排序。
7. Given 配置型卡片认证失败，When 查看卡片操作区，Then 只显示配置/校验相关动作，不显示 `Re-login`。
8. Given Codex 页面存在多个分组，When 点击某个 section 标题，Then 当前组折叠或展开，其它组状态保持不变。
9. Given 用户选择 `按额度` 排序并指定某个时间窗口，When 切换为升序或降序，Then 当前列表按所选窗口额度百分比正序或逆序排列。
10. Given 用户打开 `新增 API Key` 弹框，When 进入编辑器，Then 直接看到 `model_provider`、`API Key`、`Base URL` 三个字段，不存在高级折叠区。
11. Given 用户打开 `新增 API Key` 弹框，When 表单初始化，Then `model_provider` 默认值为 `nolon`，`API Key` 为空，`Base URL` 为空。
12. Given 用户填写 `API Key` 但不填写 `model_provider` 与 `Base URL`，When 保存，Then 仍允许创建账号。
13. Given 用户填写 `API Key` 与 `Base URL`，When 保存，Then 表单会使用用户填写的 `Base URL`，且 `model_provider` 留空时按默认 `nolon` 处理。
14. Given 用户打开 `新增 API Key` 弹框，When 查看关闭动作，Then 右上角显示统一关闭组件，底部不再重复出现 `Cancel` 按钮。
15. Given 用户在官方 API Key 或 Relay 账号卡片菜单点击 `编辑`，When 系统处理该动作，Then 打开 `CodexConfigEditorSheet` 并载入当前账号配置，而不是直接打开 `auth.json` 文件。
15a. Given 用户在 `CodexConfigEditorSheet` 修改 API Key 或 Relay 配置并点击保存，When 底层仍在执行账号写盘与 active provider config 同步，Then 弹框必须立即进入 saving 状态，显示进度反馈并阻止重复操作，直到保存完成或失败。
16. Given 用户进入 Codex 批量选择模式，When 点击多张卡片，Then 这些卡片进入选中态，且不会触发账号激活。
17. Given 用户在批量选择模式下已选中多张卡片，When 执行导出，Then 生成一个包含这些 auth.json 快照的 ZIP 文件。
18. Given 用户导入一个包含多个 auth.json 的 ZIP，When 导入完成，Then 所有合法账号被新增为卡片，非法文件被忽略并显示校验摘要。
19. Given 用户点击 `导入`，When 导入 modal 打开，Then 可以在 modal 内拖拽或选择 `.json` / `.zip` 文件。
20. Given 文件进入导入 modal，When 校验完成，Then 下方先显示候选账号列表，而不是立即导入。
21. Given 存在合法候选项，When 列表渲染完成，Then 系统自动测试全部候选项的连接状态。
22. Given 某个候选项连接测试失败，When 用户查看列表，Then 该项仍可被勾选或取消勾选。
23. Given 用户取消勾选部分候选项，When 点击 `导入选中`，Then 只导入当前勾选且合法的项。
24. Given 用户关闭导入 modal，When 再次打开，Then 上一次候选列表和测试状态不会残留。
25. Given 旧 auth 文件仍包含 `nolon.account.name`，When 系统加载或重写该文件，Then 该字段会被自动清理且卡片仍能正常显示。
26. Given 新建或更新官方 API key / Relay 卡，When 写盘完成，Then auth 文件中不再持久化 `nolon.account.name`。
27. Given 页面需要展示 Codex 卡片名称，When 生成显示名，Then 按“邮箱优先，随后 provider/host 或 key suffix，最后文件名/account”派生，而不是依赖持久化 `name` 字段。
28. Given 用户导入一个 ZIP 且其中包含多个合法账号，When 候选列表渲染完成，Then 这些候选项按同一来源组展示，并可通过组按钮一次性勾选整组。
29. Given 候选列表存在多个来源组，When 用户点击顶部 `全选`，Then 所有合法候选项都会被勾选，而不仅是当前组。
30. Given 导入 modal 正在校验或测试连接，When 用户观察底部操作区，Then 可以看到全局处理中状态，并且主导入按钮不会在校验阶段误触发。
31. Given 导入 modal 出现全局错误，When 页面渲染，Then 错误以显著 banner 展示，而不是淹没在普通说明文案里。
32. Given 用户在 Codex 卡片菜单点击 `Copy Auth JSON`，When 打开导入 modal 并执行粘贴，Then 该账号先以候选项形式出现，而不是直接导入。
33. Given 登录成功后只拿到 `http://localhost:1455/success?id_token=...` 回调 URL，When 在导入 modal 粘贴该 URL，Then 系统会解析成候选账号并自动测试连接。
34. Given 本地登录服务最终落在任意合法 loopback 回调地址（如 `http://localhost:<port>/auth/callback?...`、`http://127.0.0.1:<port>/success?...` 或 `http://[::1]:<port>/auth/callback?...`），When 在导入 modal 粘贴该 URL，Then 系统会复用 Codex callback 解析器按相同规则解析成候选账号。
35. Given 用户点击 Codex 登录，When app-server 登录失败，Then 页面直接显示错误，不再 fallback 到 direct CLI 并自动打开浏览器。
36. Given 用户看到 Codex 登录 URL 弹窗，When 需要结束登录，Then 界面只提供一个明确的 `取消登录` 动作，而不是两个等价按钮。
37. Given UI 验证需要直接进入 Codex 用量页，When 通过 UI Test 环境变量指定 provider index 与 tab，Then app 启动后会直接落在对应 Provider 的目标 tab，避免人工点击切页。

## 影响实现点
- `ProviderContentTabType`：新增按 Provider 解析 usage 名称能力。
- `ProviderUsageView`：按 active 卡类型切换 Codex 头部按钮布局，并支持 section 折叠。
- `ProviderUsageView`：支持 Codex 卡片批量选择模式、ZIP 导入导出入口和选中态渲染。
- `ProviderUsageView`：新增 Codex 导入 modal、拖拽导入区、候选账号列表与行内连接测试状态。
- `ProviderUsageView`：导入候选列表按来源分组渲染，支持整组选择和全局全选。
- `ProviderUsageView`：Codex 卡片菜单新增 `Copy Auth JSON`，导入 modal 新增 `粘贴` 入口。
- `Localizable.xcstrings`：新增 `tab.account_usage`、`codex.accounts.refresh_all`。
- `CodexLoginRunner`：新增 localhost callback URL（`/success` / `/auth/callback`）-> auth JSON 解析能力，并兼容只有 `id_token` 的外部 token 恢复导入。
- `CodexAuthSummary`：扩展 `cardKind/name/relayBaseURL/relayModelProvider` 解析。
- `CodexAuthManager`：新增配置型账号写回能力，并为 auth 文件补齐 `nolon.account.kind/updatedAt`。
- `CodexAuthManager`：新增选中账号 ZIP 导出、ZIP 解压导入预处理能力。
- `CodexAuthManager`：弃用 `nolon.account.name` 的持久化写入；旧文件在加载/保存时自动清理该字段。
- `ProviderUsageViewModel`：新增 `CodexAccountGroupingOption`、`CodexAccountSortOption`、`CodexPrimaryHeaderAction`、`codexAccountDisplaySections`、分组折叠状态，并抽出配置编辑器标题/副标题/主按钮文案。
- `ProviderUsageViewModel`：新增导入 modal 状态、候选项分组/选择状态、自动连接测试与按选中项导入逻辑。
- `CodexConfigEditorSheet`：改成简化直出编辑器，只保留 `model_provider / API Key / Base URL` 三个字段。

## 进展更新（2026-04-17：API Key 明文展示与保存反馈）
1. 用户新增交互要求：
   - `API Key` 输入框不再使用密文遮罩，编辑态直接展示明文值。
   - 用户修改 API Key 后点击保存时，弹框不能表现为“卡住”，而要立即给出保存中反馈。
2. 代码链路结论：
   - `API Key` 的密文展示仅由 `CodexConfigEditorSheet` 中的 `SecureField` 导致。
   - 保存动作会等待 `updateConfiguredAccount(...)` 与当前激活账号的 `refreshActiveProviderConfigIfNeeded(...)` 完成；这段等待本身是预期行为，但旧 UI 没有 saving 态，容易被误判为卡顿。
3. 本轮收敛方案：
   - 将 `CodexConfigEditorSheet` 的 `API Key` 输入改为 `TextField`。
   - 为 Codex config editor 增加 `isSaving` 状态，保存中显示 `ProgressView`，并禁用关闭、校验和重复保存操作。
4. 回归验证要求：
   - `CodexConfigEditorSheetSnapshotTests` 需验证编辑态不存在 `NSSecureTextField`，且保存中能看到进度指示。

## 补充更新（2026-04-17：编辑态写回与重开回填）
1. 新增缺陷反馈：
   - 用户修改已存在账号的 `API Key` 后再次打开编辑器，看到的仍是旧值。
   - 用户再次编辑时，只要把 `API Key` 删除到空字符串，编辑器主体就会消失。
2. 根因定位：
   - `CodexConfigEditorSheet` 对 `@Binding var draft: CodexConfigEditorDraft?` 使用了 `draft?[keyPath:] = value` 与 `draft?.modelProvider = option` 这种可选结构体的隐式局部写回。
   - 该写法不会稳定触发整个 `draft` 回写到 `ProviderUsageEngine.codexConfigEditorDraft`，导致界面临时值、保存值与重开回填值可能不一致；在删除到空字符串时，这个丢失风险会表现为编辑器主体消失。
3. 本轮收敛方案：
   - `CodexConfigEditorSheet` 新增 `updatedDraft(...)`，把所有字段更新统一改为显式整包写回。
   - `API Key`、`Name`、`Base URL` 与 `model_provider` 菜单都走同一条显式写回路径，避免可选 draft 局部修改丢失。
   - 持久化层不改协议与 SQLite 语义，只修编辑页草稿状态同步链路。
4. 回归验证要求：
   - `CodexConfigEditorSheetSnapshotTests` 新增用例，验证显式写回后即使把 `API Key` 改成空字符串，draft 仍然存在。
   - `ProviderUsageEngineValidateConfiguredAccountTests` 新增用例，验证保存新 `API Key` 后重新打开编辑器会回填新值。
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexConfigEditorSheetSnapshotTests` 通过（5 tests）
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageEngineValidateConfiguredAccountTests` 通过（12 tests）

## 补充更新（2026-04-17：配置型账号保存链路瘦身）
1. 新增性能边界：
   - `Usage` 已拆到其他页面，账号编辑页不再需要为了保存单个账号触发整页 usage 重算。
   - 当前需求仅覆盖“编辑单个配置型账号后，本页状态立即正确、active 运行态必要同步正确”。
2. 根因定位：
   - 原 `saveCodexConfigEditor()` 在编辑已存在账号时，会串行等待 `updateConfiguredAccount(...)`、`refreshActiveProviderConfigIfNeeded(...)` 和手动 `reloadCodexFromDisk(refreshUsage: false)`。
   - 其中手动 `reloadCodexFromDisk` 会全量重载 `accounts / summaries / outcomes / grouping / active id / watcher`，而 GRDB SQLite observation 写库后还会再触发一次刷新，导致“编辑一个账号”退化成“前台做两次全量同步”。
   - `activeAccountId(for:)` 旧实现内部还会再次 `loadAccounts()`，把已经在内存里的 `codexAccounts` 又重新扫了一遍 SQLite。
3. 本轮收敛方案：
   - 去掉保存成功后的手动全量 `reloadCodexFromDisk(refreshUsage: false)`，改为先本地 patch `codexAccounts / summaries / outcomes`，由 observation 作为后台兜底刷新。
   - `activeAccountId(for:)` 新增复用已加载 `accounts` 的重载，避免保存和显示链路里重复 `loadAccounts()`。
   - active 配置型账号保存时按字段 diff 决定同步范围：
     - 仅改 `name`：`none`
     - 仅改 `API Key`：只刷新 active `auth.json`
     - Relay 相关字段变更：刷新 `auth.json + config.toml`
   - `CodexActiveProviderConfig` 内部补充 provider migration 去重，避免相同 providerID 的重复 session migration。
4. 验收与回归要求：
   - 保存新 `API Key` 后，立刻重新打开编辑器，看到的是本地 patch 后的新值，不依赖下一轮全量 reload。
   - active 官方 API key 账号只改 `API Key` 时，`auth.json` 更新，但 `config.toml` 保持不变。
   - active relay 账号改 `Base URL` 时，托管 `config.toml` 会按新 relay 配置重写。
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageEngineValidateConfiguredAccountTests` 通过（15 tests）
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexConfigEditorSheetSnapshotTests` 通过（5 tests）

## 后续扩展
- HTTP 用量查询能力已单独落到 [codex-http-usage-query-2026-03-07.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/features/codex-http-usage-query-2026-03-07.md)，并作为配置型卡片的可选能力接在 Codex CLI 用量链路前面。
- `nolon.account.name` 已弃用：
  - 新 auth 文件不再写这个字段
  - 旧文件在加载/保存时自动迁移清理
  - 运行时显示名改为派生规则，优先使用邮箱，再回退到 relay provider/host、API key suffix、文件名或 `account`

## 增补（2026-03-13：隐藏无额度账号）
1. Codex 账号卡片区新增显式筛选按钮：
   - 默认显示 `隐藏无额度账号`
   - 开启后切换为 `显示全部账号`
2. 筛选仅作用于 Codex 账号卡片列表：
   - 不影响顶部管理卡
   - 不影响 Token Trend 区块
   - 不影响非 Codex Provider
3. “无额度”定义固定为：
   - 仅对 `.tokenAccount` 生效
   - 取账号所有 quota window 中 `windowMinutes` 最大的一项
   - 若该最长窗口存在且 `remainingPercent == 0`，则该账号在筛选开启时被隐藏
   - 若账号没有任何 quota window 数据，则继续显示
   - 不使用 `credits.remaining` 参与该判定
4. 筛选顺序固定为“先过滤，再排序/分组”，避免改变现有排序语义。
5. 筛选状态按 provider 维度持久化，重新进入同一 provider 时沿用上次选择，不影响其他 provider。
6. 当筛选开启且所有账号都被过滤时，页面显示明确空态，提示用户当前是因为筛选而不是因为没有账号。

### 补充 BDD 验收
1. Given 当前 Provider 为 Codex 且用户开启 `隐藏无额度账号`，When 某个账号最长 quota window 的剩余比例为 0%，Then 该账号不出现在卡片列表中。
2. Given 当前 Provider 为 Codex 且用户开启 `隐藏无额度账号`，When 某个账号最长 quota window 的剩余比例大于 0%，Then 该账号继续显示。
3. Given 当前 Provider 为 Codex 且用户开启 `隐藏无额度账号`，When 某个账号没有任何 quota window 数据，Then 该账号继续显示。
4. Given 某个账号同时存在多个 quota window，When 判断是否隐藏，Then 必须以 `windowMinutes` 最大的那一个窗口作为唯一判定依据。
5. Given 当前 Provider 为 Codex 且筛选后所有账号都被隐藏，When 页面渲染，Then 显示“已隐藏无额度账号，可关闭筛选查看全部”的空态提示。
