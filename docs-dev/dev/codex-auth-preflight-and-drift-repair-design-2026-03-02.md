# Codex Auth Preflight 与漂移恢复设计（2026-03-02）

## 代码落点
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift`
- `libs/Providers/Sources/ProviderUsage/CodexAuthAccount.swift`
- `nolon/Skills/Views/Provider/Usage/ProviderUsageViewModel.swift`
- `nolon/nolonApp.swift`

## 关键实现

### 1) Provider 识别与路径
- `CodexAuthManager.codexHomeFolder(for:)` 支持 `codex` 与 `codexXcode`。
- `ProviderUsageViewModel.mapToUsageProvider` 将 `codexXcode` 映射到 `.codex`。

### 2) matchAccount 优先级
- 新顺序：`email -> accountID -> apiKeySuffix -> cleaned JSON 全等`。
- `CodexAuthSummary` 新增 `accountID` 解析，覆盖：
  - `account.id`
  - `tokens.account_id/accountId`
  - `chatgpt_account_id/chatgptAccountId`
  - `account_id/accountId`
  - `nolon.account.id`

### 3) preflight 主流程
新增 `preflightManagedAuthIfNeeded(for:forceBackup:reason:)`：
1. 迁移旧数据。
2. 文件锁内执行 provider auth 与快照对齐（regular file 迁移、软链修复、active 注册修复）。
3. 文件锁内执行漂移检测与恢复。
4. 备份 active 快照（按策略）。
5. 更新 active 指纹。

### 4) 文件锁
- 新增锁文件：`~/.nolon/codex/.auth.lock`
- 使用 `open + flock(LOCK_EX)` 串行化关键读写，降低并发破坏风险。

### 5) 真值评分
`resolvePreferredSourceCandidate` 对 provider/snapshot 打分，主要因子：
- 数据可解析
- 凭据可导入
- email/accountID/api key 信息完整度
- 快照近期同步成功加分
同分时默认 provider 优先。

注意：`nolon.account.id` 是本地 UUID，不参与评分加分，避免影响 provider 判真值。

### 6) 漂移检测与恢复
基于 cleaned-auth hash：
- 指纹文件：`~/.nolon/codex/active-fingerprints.json`
- 若 active hash 与历史指纹不一致：
  - 查找备份（优先按 account 前缀，失败时全目录按 hash 匹配）
  - 若身份变化（email/accountID）成立：
    - 恢复 active 备份
    - 将漂移数据写入新/匹配快照（排除 active）
    - 重建软链并修复 active 注册

### 7) 备份策略
- 目录：`~/.nolon/codex/backups/active/<provider-id>/`
- 命名：`<account-id>-<unix-ts>.json`
- 创建间隔：>= 5 分钟（`forceBackup=true` 时强制）
- 清理策略：最多 10 份 + 删除 30 天前文件

### 8) 后台轮询
在 `nolonApp` 增加 `CodexAuthBackgroundPoller`：
- 默认开启（UserDefaults key: `codex.auth.background_poll.enabled`）
- 间隔：60 秒
- 范围：仅 `codex/codexXcode` provider
- 动作：执行 preflight（非强制备份）

## 测试覆盖

### ProvidersTests
- `CodexAuthManagerTests` 新增：
  1. `codexXcode` home path 可用
  2. `matchAccount` 邮箱优先
  3. `matchAccount` accountID 优先
  4. provider 损坏时 preflight 选快照
  5. 外部改写 active 时 preflight 恢复 + 承接漂移账号

### nolonTests
- `ProviderUsageViewModelManualRefreshTests` 新增：
  - `codexXcode` -> `.codex` 映射与多账号启用断言

## 已知限制
- 后台轮询是 app 进程内策略；若 app 完全退出，不会执行自愈。
- 当前“补全身份”依赖 auth 内容解析和现有刷新链路，未引入额外网络探测步骤。
