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
10. `新增 API Key / 新增 Relay / 编辑配置` 弹框采用基础信息优先的分层结构：
   - 顶部使用标题 + 副标题说明当前模式
   - 基础信息单独放在首屏 section
   - `新增 API Key` 仅 `名称 + API Key` 为必填
   - `新增 API Key` 的 `Base URL` 收进可选高级项，并默认预填官方地址 `https://api.openai.com/v1`
   - Relay 的 query/header 收进 `Advanced`
   - HTTP 用量查询收进独立折叠区，`Credentials Override` 与 `Mapping` 再次折叠
   - `Test Request` 放在 HTTP 区块内部，不再占用顶部 toolbar
   - 底部主按钮文案按模式切换为 `Create` / `Save`
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
10. Given 用户打开 `新增 API Key` 或 `新增 Relay` 弹框，When 进入编辑器，Then 先看到最小可用的基础字段，而不是被 HTTP 和高级配置淹没。
11. Given 用户打开 `新增 API Key` 弹框，When 未展开高级项直接填写，Then 只需填写 `名称 + API Key`，且 `Base URL` 默认使用官方地址。
12. Given 用户需要配置 HTTP 用量查询，When 展开 HTTP 区块，Then 仍可以在同一弹框中完成配置和测试请求。
13. Given 用户进入 Codex 批量选择模式，When 点击多张卡片，Then 这些卡片进入选中态，且不会触发账号激活。
14. Given 用户在批量选择模式下已选中多张卡片，When 执行导出，Then 生成一个包含这些 auth.json 快照的 ZIP 文件。
15. Given 用户导入一个包含多个 auth.json 的 ZIP，When 导入完成，Then 所有合法账号被新增为卡片，非法文件被忽略并显示校验摘要。
16. Given 用户点击 `导入`，When 导入 modal 打开，Then 可以在 modal 内拖拽或选择 `.json` / `.zip` 文件。
17. Given 文件进入导入 modal，When 校验完成，Then 下方先显示候选账号列表，而不是立即导入。
18. Given 存在合法候选项，When 列表渲染完成，Then 系统自动测试全部候选项的连接状态。
19. Given 某个候选项连接测试失败，When 用户查看列表，Then 该项仍可被勾选或取消勾选。
20. Given 用户取消勾选部分候选项，When 点击 `导入选中`，Then 只导入当前勾选且合法的项。
21. Given 用户关闭导入 modal，When 再次打开，Then 上一次候选列表和测试状态不会残留。
22. Given 旧 auth 文件仍包含 `nolon.account.name`，When 系统加载或重写该文件，Then 该字段会被自动清理且卡片仍能正常显示。
23. Given 新建或更新官方 API key / Relay 卡，When 写盘完成，Then auth 文件中不再持久化 `nolon.account.name`。
24. Given 页面需要展示 Codex 卡片名称，When 生成显示名，Then 按“邮箱优先，随后 provider/host 或 key suffix，最后文件名/account”派生，而不是依赖持久化 `name` 字段。
26. Given 用户导入一个 ZIP 且其中包含多个合法账号，When 候选列表渲染完成，Then 这些候选项按同一来源组展示，并可通过组按钮一次性勾选整组。
27. Given 候选列表存在多个来源组，When 用户点击顶部 `全选`，Then 所有合法候选项都会被勾选，而不仅是当前组。
28. Given 导入 modal 正在校验或测试连接，When 用户观察底部操作区，Then 可以看到全局处理中状态，并且主导入按钮不会在校验阶段误触发。
29. Given 导入 modal 出现全局错误，When 页面渲染，Then 错误以显著 banner 展示，而不是淹没在普通说明文案里。
30. Given 用户在 Codex 卡片菜单点击 `Copy Auth JSON`，When 打开导入 modal 并执行粘贴，Then 该账号先以候选项形式出现，而不是直接导入。
31. Given 登录成功后只拿到 `http://localhost:1455/success?id_token=...` 回调 URL，When 在导入 modal 粘贴该 URL，Then 系统会解析成候选账号并自动测试连接。
32. Given 本地登录服务最终落在任意合法 loopback 回调地址（如 `http://localhost:<port>/auth/callback?...`、`http://127.0.0.1:<port>/success?...` 或 `http://[::1]:<port>/auth/callback?...`），When 在导入 modal 粘贴该 URL，Then 系统会复用 Codex callback 解析器按相同规则解析成候选账号。
33. Given 用户点击 Codex 登录，When app-server 登录失败，Then 页面直接显示错误，不再 fallback 到 direct CLI 并自动打开浏览器。
34. Given 用户看到 Codex 登录 URL 弹窗，When 需要结束登录，Then 界面只提供一个明确的 `取消登录` 动作，而不是两个等价按钮。
35. Given UI 验证需要直接进入 Codex 用量页，When 通过 UI Test 环境变量指定 provider index 与 tab，Then app 启动后会直接落在对应 Provider 的目标 tab，避免人工点击切页。

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
- `CodexConfigEditorSheet`：改成基础信息优先的分层编辑器，支持 Advanced / HTTP / Mapping 折叠。

## 后续扩展
- HTTP 用量查询能力已单独落到 [codex-http-usage-query-2026-03-07.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-dev/features/codex-http-usage-query-2026-03-07.md)，并作为配置型卡片的可选能力接在 Codex CLI 用量链路前面。
- `nolon.account.name` 已弃用：
  - 新 auth 文件不再写这个字段
  - 旧文件在加载/保存时自动迁移清理
  - 运行时显示名改为派生规则，优先使用邮箱，再回退到 relay provider/host、API key suffix、文件名或 `account`
