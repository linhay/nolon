# Codex Auth JSON 导入格式（含批量数组）

## 背景
Codex 账号导入支持拖拽/选择文件、粘贴 JSON、粘贴 localhost 登录回调链接。为了兼容不同来源的 auth 导出，需要支持多种 JSON 结构，并保证导入后能被现有读取逻辑使用。

本轮在导入面板中追加“导出选中”能力：用户把候选账号加进面板后，不必先落盘到 `~/.nolon/codex/auth`，即可直接按当前勾选结果导出。

## 支持的输入
### 1) 单对象 JSON
支持两类等价写法：

1. 标准结构（推荐）
- `tokens.id_token`
- `tokens.access_token`
- 可选：`tokens.refresh_token`、`tokens.account_id`

2. 顶层字段结构（兼容）
- 顶层 `id_token` / `access_token` / `refresh_token` / `account_id`
- 可选：`last_refresh`、`email`、`expired`、`type`

### 2) 批量数组 JSON（新增）
文件内容为数组：
- `[ { ...单对象... }, { ...单对象... } ]`

数组内每个元素都会被视为一个独立账号候选项参与验证与导入。

### 3) ZIP（保持）
ZIP 中的每个 `.json` 文件都会被视为候选；若某个 `.json` 的内容是数组，则按数组规则展开为多个候选项。

## 导入落盘规范化（强制）
导入保存到 `~/.nolon/codex/auth/*.json` 时，对输入进行规范化以保持内部一致性：

1. 将顶层 token 字段迁移到 `tokens.*`
- `id_token` -> `tokens.id_token`
- `access_token` -> `tokens.access_token`
- `refresh_token` -> `tokens.refresh_token`
- `account_id` -> `tokens.account_id`
- 若输入已包含 `tokens.*`，仅补齐缺失字段，不覆盖已有值。
- 迁移后删除顶层同名字段，避免双源漂移。

2. 过期字段映射
- 若存在顶层 `expired` 且未提供 `expires_at/expiresAt`，写入 `expires_at = expired`，并删除 `expired`。

3. 类型校验
- 若输入包含 `type` 且不为 `codex`（忽略大小写），则该候选项无效。

## Email 推断（用于展示与匹配）
`email` 的候选来源：
1. 顶层 `email`
2. `user.email`
3. `nolon.account.email`

## 导入面板导出（新增）
在 `导入账号` 面板中，候选账号完成校验后，支持基于当前选择态直接导出：

1. `导出 ZIP`
2. `导出 sub2api`

约束：
1. 仅导出 `isValid == true && isSelected == true` 的候选项。
2. 不要求用户先点击 `导入选中`。
3. `导出 ZIP` 输出候选 auth JSON 的聚合压缩包。
4. `导出 sub2api` 复用正式账号页相同映射规则：
   - OAuth -> `oauth`
   - 官方 API Key -> `apikey`
   - relay -> 跳过并提示数量

## 导入面板搜索（新增）
为便于在大量候选项中快速定位账号，`导入账号` 面板追加本地搜索框。

规则：
1. 搜索仅影响候选列表展示，不改变候选项的校验状态、勾选状态与导出结果。
2. 默认搜索范围包含：
   - `suggestedName`
   - `email`
   - 文件名
   - 来源组标题
   - 校验失败原因
3. 搜索为空时显示全部候选项。
4. 搜索无命中时显示“无搜索结果”空状态，而不是“还没有候选账号”。
5. 导入面板初始打开且尚无候选项时，不显示下方候选工具栏与列表区域，只保留拖拽/选择/粘贴入口。

## BDD 验收
1. Given 用户在导入面板中加入多个有效候选项，When 勾选其中一部分并点击 `导出 ZIP`，Then 仅导出选中的有效候选项。
2. Given 导入面板选中 OAuth 与官方 API Key 候选项，When 点击 `导出 sub2api`，Then 输出文件包含 `oauth` 与 `apikey` 两类账号。
3. Given 导入面板的选中集合中包含 relay，When 点击 `导出 sub2api`，Then relay 不进入结果文件，且提示包含跳过数量。
4. Given 导入面板没有选中任何有效候选项，When 点击导出动作，Then 阻止导出并提示先选择账号。
5. Given 导入面板存在多个来源组与候选项，When 用户输入邮箱、建议名称或文件名关键字，Then 列表仅展示匹配的候选项，并保留仍有命中的来源组。
6. Given 导入面板已有候选项但搜索无命中，When 列表刷新，Then 显示“无搜索结果”状态，并允许用户清空搜索后恢复全部候选项。

## 导入面板在线测试（调整）
导入面板里的“测试连接”只用于验证候选 auth 是否携带显式 HTTP usage query 配置：

1. 仅当 auth JSON 存在显式 `nolon.usage_query` 时，才执行 HTTP usage query。
2. 不再因为缺少显式 HTTP 配置而自动回退到 CLI / JSON-RPC。
3. 对普通 OAuth 候选项，如果未携带显式 HTTP 配置，则显示“未配置 HTTP 用量查询，已跳过在线测试；仍可继续导入”。

### BDD 验收
1. Given 导入面板中的候选 auth 含显式 `nolon.usage_query`，When 自动测试连接，Then 执行 HTTP usage query 并显示 HTTP 结果。
2. Given 导入面板中的候选 auth 不含显式 `nolon.usage_query`，When 自动测试连接，Then 不触发 CLI / JSON-RPC，而是显示跳过在线测试说明。
