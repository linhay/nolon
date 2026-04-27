# Claude Code 账号数据库迁移 Phase 1（2026-04-02）

## 背景
- Claude 账号目前仍以 `accounts.json` 与 `active-account.json` 存储。
- 项目已存在统一 SQLite 文件 `nolon.sqlite3`（Codex 账号正在使用），Claude 需要对齐到数据库体系。

## 本期目标
1. 先完成数据库建表，为后续数据迁移与读写切换打基础。
2. 不改变当前 Claude 账号线上读写行为（继续走 JSON 文件），避免一次性风险。

## 范围
1. 在 `ClaudeAccountManager.ensureStorage()` 增加 SQLite schema 初始化。
2. 新建 `claude_accounts` 表。
3. 新建 `claude_active_accounts` 表，并初始化默认 scope 行（`default`）。
4. 增加测试校验表已创建。

## 非目标
1. 本次不把现有 `accounts.json` 数据回填进 SQLite。
2. 本次不切换 Claude 账号查询/写入到 SQLite。
3. 本次不删除 JSON 文件通路。

## BDD 验收场景
1. Given 首次初始化 Claude 账号存储，When 调用 `loadAccounts()`，Then `nolon.sqlite3` 自动创建。
2. Given `nolon.sqlite3` 已创建，When 检查 schema，Then 存在 `claude_accounts` 与 `claude_active_accounts` 两张表。
3. Given 初始化完成，When 查询 `claude_active_accounts`，Then 存在 `scope='default'` 的默认行。

## 下一步
1. Phase 2：把 JSON 快照迁移到 SQLite（一次性 backfill + 幂等）。
2. Phase 3：读路径切换到 SQLite，写路径双写/切换。
3. Phase 4：移除 JSON 旧路径与兼容代码。

## 进展更新（2026-04-02）
1. 已完成 Phase 2/3 的最小闭环：
2. `loadAccounts`、`saveAccounts`、`activeAccountID`、`setActiveAccountID` 已切换到 SQLite 主路径。
3. 保留 JSON 镜像写入，确保旧版本/调试脚本可读。
4. 新增“首次迁移”逻辑：当 SQLite 为空时，自动从 `accounts.json` / `active-account.json` 回填。
5. 回填策略为幂等：仅在 SQLite 无账号时执行，避免覆盖数据库内新数据。

## 进展更新（2026-04-02，第二次）
1. 已完成 Phase 4 的运行时收口：移除 `saveAccounts` 与 `setActiveAccountID` 的 JSON 镜像写入。
2. `ensureStorage` 不再预创建空 `accounts.json` / `active-account.json`。
3. 仍保留旧 JSON 的首启回填能力（仅 SQLite 为空时生效），确保平滑升级。
4. 新增测试覆盖：新增账号并激活后，不会再生成旧 JSON 快照文件。
