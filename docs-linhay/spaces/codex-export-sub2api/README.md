# Codex 账号导出 sub2api（2026-03-11）

## 背景
当前 Codex 账号页已经支持批量导出原始 `auth.json` ZIP 快照，但还不能直接导出为 `sub2api-data` 聚合格式。用户希望把 Nolon 中维护的 Codex 账号直接交给 sub2api 使用。

## 范围
1. 保留现有 `导出 ZIP`。
2. 新增并列动作 `导出 sub2api`。
3. 导出来源复用 `~/.nolon/codex/auth/*.json`。
4. 支持两类账号：
   - ChatGPT OAuth
   - 官方 OpenAI API Key
5. `relayProfile` 不导出到 sub2api，导出完成后明确提示跳过数量。
6. CLI 新增 `nolon codex auth export --format sub2api`。
7. `导入账号` 面板中的已校验候选项也支持直接 `导出 sub2api`，不要求先导入落盘。

## 非目标
1. 不替换现有 ZIP 导出。
2. 不新增 sub2api 导入。
4. 不把 relay 强行映射成 sub2api `apikey`。

## sub2api 输出约束
导出文件必须是单个 JSON，顶层结构：

```json
{
  "type": "sub2api-data",
  "version": 1,
  "exported_at": "2026-03-11T11:50:00+08:00",
  "proxies": [],
  "accounts": []
}
```

账号映射：
1. OAuth -> `platform=openai`, `type=oauth`
2. 官方 API Key -> `platform=openai`, `type=apikey`
3. Relay -> 跳过，不写入 `accounts`

## BDD 验收
1. Given 用户在 Codex 页面进入多选并选中多个 OAuth 账号，When 点击 `导出 sub2api`，Then 生成一个 `sub2api-data` JSON 文件。
2. Given 用户同时选中 OAuth 与官方 API Key，When 导出，Then `accounts` 同时包含 `oauth` 与 `apikey` 项。
3. Given 选中集合中包含 relay，When 导出，Then relay 不进入导出结果，且提示包含“跳过 X 个 relay 账号”。
4. Given 用户只选中了 relay，When 导出，Then 不生成有效结果，并提示没有可导出的 sub2api 账号。
5. Given 用户未选择任何账号，When 点击 `导出 sub2api`，Then 阻止导出并提示先选择账号。
6. Given 用户完成 `导出 sub2api`，When 返回账号页，Then 多选模式退出并清空选择。
7. Given 用户在 CLI 执行 `nolon codex auth export --format sub2api --all --output <path>`，When 命令成功，Then 指定路径生成 sub2api JSON 文件并返回导出统计。
8. Given CLI 目标集合中包含 relay，When 导出，Then 文件仍生成，但输出统计包含 `skippedRelayCount`。
9. Given 用户在 `导入账号` 面板中加入多个候选项，When 选择其中一部分并点击 `导出 sub2api`，Then 只转换当前选中的有效候选项。

## UI 反馈
1. 成功全部导出：`已导出 %d 个账号为 sub2api。`
2. 部分跳过 relay：`已导出 %d 个账号为 sub2api，跳过 %d 个 relay 账号。`
3. 全部不支持：`所选账号中没有可导出的 sub2api 账号。`
