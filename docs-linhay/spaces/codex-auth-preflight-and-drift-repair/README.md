# Codex 多账号一致性修复（2026-03-02）

## 背景
在 `codex/codexXcode` 同时存在 provider `auth.json` 与 Nolon 快照时，刷新链路可能继续使用旧快照；同时外部 `codex cli` 在软链路径写入会污染 active 快照，导致账号偏移。

## 目标
1. 刷新前统一执行 preflight，自愈 provider auth 与快照不一致。
2. 顶部刷新和账号页刷新都覆盖报错账号。
3. 支持 `codexXcode` 与 `codex` 同一套账号管理逻辑。
4. 在无文件监听前提下，后台轮询也可发现并修复账号漂移。

## 用户可见行为
1. `codexXcode` 在“账号与用量”中按 Codex 多账号行为处理。
2. 顶部“刷新”前会先做账号一致性 preflight。
3. provider `auth.json` 不是软链时，会自动迁移回快照并重建软链。
4. 外部 CLI 改写 active 快照时，会自动恢复 active 并将漂移数据入新/匹配快照。
5. 读取快照列表时会自动修复历史脏元数据：`nolon.account.relativeAuthPath` 与实际文件路径不一致、以及 `nolon.account.id` 跨文件重复。
6. 读取快照列表时会自动清理“重复 payload 文件”：若两个快照去除 `nolon` 元数据后内容完全一致，仅保留一份并删除重复文件。
7. 账号切换（activate）默认仅执行磁盘层切换，不再同步等待 runtime `account/updated` 通知；runtime 切换改为可独立触发的手动能力。
8. provider `auth.json` 已断链且 active registry 失效时，preflight 会按 active 指纹或单快照兜底重建软链，再继续执行漂移恢复。
9. `app-server` 登录完成后，系统会在短窗口内轮询等待 `auth.json` 落盘，再执行快照写入；避免“登录成功但文件尚未同步”导致回退链路误覆盖旧账号。

## 匹配与判定规则
1. `matchAccount` 对含 `account_id` 的 payload 采用严格身份判定：
   - `account_id + email` 命中才允许覆盖；
   - 若缺失 `email`，仅 `account_id + nolon.account.id` 同时命中才允许覆盖；
   - 仅 `account_id` 命中时不覆盖，改为新建快照。
2. 对不含 `account_id` 的 payload，继续按 `OPENAI_API_KEY（完整值精确匹配） -> email -> cleaned-json` 判定。
3. 自愈链路（detached reconcile / drift repair）与主匹配使用同一身份判定规则，避免“同工作空间不同用户”被误合并。
4. provider auth 与 snapshot 冲突时使用评分选真值；同分时优先 provider。
5. `nolon.account.id`（UUID）不作为评分加分项，避免误压制 provider 结果。

## 备份与恢复
1. 仅备份 active 快照。
2. 触发点：进入用量页（load）、手动刷新、漂移修复流程。
3. 周期：5 分钟最小间隔。
4. 保留：最多 10 份，且清理 30 天前备份。
5. 快照自愈策略：按文件名排序保留首个 `account.id`，后续重复 ID 自动重置为新 UUID（仅修复元数据，不改动 token 字段）。
6. payload 去重策略：按 cleaned payload hash 分组，优先保留活跃账号映射对应项，其次按创建时间早、路径字典序小；删除其余重复文件并同步修正 active map。
7. 激活基线策略：账号切换（activate）完成后立即落 active 备份并刷新 active 指纹，避免“切换后瞬时漂移”因缺少基线而无法恢复。
8. 断链兜底策略：若 preflight 首轮发现 `auth.json` 断链且 registry 指向失效，会优先按 active 指纹回链；若仅有一个快照则直接回链该快照，确保后续漂移恢复可继续。

## 验收（BDD）
1. Given detached provider auth 与匹配快照，When preflight，Then 以 provider 内容覆盖快照并重建软链。
2. Given detached provider auth 无匹配快照，When preflight，Then 创建新快照并重建软链。
3. Given provider auth 损坏而快照健康，When preflight，Then 保持快照为真值并重建软链。
4. Given active 快照被外部改写，When preflight，Then 恢复 active 并保留漂移账号数据到新/匹配快照。
5. Given 两个快照 `OPENAI_API_KEY` 后缀相同但完整值不同，When 记录登录快照，Then 只更新完整值相同的账号，不得覆盖到较新但仅后缀相同的文件。
6. Given 两个快照文件拥有相同 `nolon.account.id` 且其中一个 `relativeAuthPath` 错误，When 读取账号列表，Then 重复 ID 会被重置，且错误路径元数据会被修正为当前文件路径。
7. Given 两个快照文件 cleaned payload 完全一致，When 读取账号列表，Then 自动删除重复文件并仅保留一份可用快照。
8. Given active 快照被外部改写且触发文件名自愈导致 `auth.json` 断链，When preflight，Then 会先兜底重建软链并继续恢复 active 与承接漂移数据。
9. Given app-server 已返回 login completed 但 `auth.json` 延迟落盘，When 登录流程继续，Then 会等待文件同步后再写快照，不应立刻回退并误用旧 auth 数据。

## 增补（2026-03-02：CLI 登录目录稳定化）
### 问题
1. 部分环境登录成功后未新增账号卡片，且 `cli-login-home` 下看不到新的 `auth.json`。
2. 触发条件之一是登录链路使用临时目录或 keyring 存储，导致 `auth.json` 不稳定落盘，后续快照记录阶段拿不到新 auth payload。

### 修复
1. `ProviderUsageViewModel` 登录链路改为固定目录：`~/.nolon/{provider}/cli-login-home/{provider}/`，不再使用临时目录。
2. 登录前强制写入 `config.toml`：`cli_auth_credentials_store = "file"`，确保凭证落盘到文件。
3. 登录前删除该隔离目录中的旧 `auth.json`，避免误读陈旧 payload。
4. `NolonCoreCLI.authLogin` 同步执行相同预处理，保证 App 与 CLI 行为一致。

### 验收（新增）
1. Given 隔离 `NOLON_HOME`，When 调用 `prepareCLILoginHomeDirectory`，Then 返回稳定目录并写入 `file` 存储配置。
2. Given 登录目录已有陈旧 `auth.json`，When 再次 prepare，Then 会先清理旧文件。
3. Given CLI `auth login` 路径，When 执行登录前预处理，Then 同样强制 `file` 配置并清理旧 `auth.json`。

## 增补（2026-03-02：app-server 完成事件丢失兜底）
### 问题
1. 现场出现 `cli-login-home/codex/auth.json` 已生成，但 UI 仍停留“登录中”，账号卡片不新增。
2. 根因是 app-server 登录链路先等待 `login completed` 事件，再读取 `auth.json`；事件丢失时会卡住或误回退 direct flow。

### 修复
1. 新增 `CodexLoginRunner.awaitAuthResultPreferFile`：以 `auth.json` 落盘作为主成功信号。
2. app-server completion 改为 best-effort 并行等待，失败不阻断 `auth.json` 同步。
3. App（`ProviderUsageViewModel`）与 CLI（`NolonCodexCLI.loginViaAppServer`）统一切换到该策略。

### 验收（新增）
1. Given completion waiter 抛错且 `auth.json` 延迟落盘，When 执行 `awaitAuthResultPreferFile`，Then 登录仍判定成功并返回 auth payload。

## 增补（2026-03-03：app-server 登录不自动打开浏览器）
### 变更
1. App UI 的 app-server 登录流程移除自动 `NSWorkspace.open(...)`。
2. CLI `nolon codex auth login` 的 app-server 登录流程移除自动 `/usr/bin/open`。
3. 统一改为只提供登录 URL（UI 弹框 / CLI 输出），由用户手动打开。

### 验收（新增）
1. Given app-server 登录启动，When 返回 `auth_url`，Then 不会自动拉起系统浏览器。

## 增补（2026-03-03：手动打开浏览器登录体验收敛）
### 变更
1. 登录 URL 弹框只要消失（Close / Esc / 外部关闭），都视为用户放弃本次登录并立即取消登录任务。
2. 弹框按钮文案由“重新打开浏览器”统一为“在浏览器中打开”。
3. app-server 登录初始化 `clientName` 调整为 `codex`，便于 OAuth 链路中的 `originator` 与 Codex 客户端标识保持一致。
4. `awaitAuthResult` 对 `auth.json` 的“非 UTF-8 瞬时态”改为继续轮询，避免文件写入中间态导致误判失败。

### 验收（新增）
1. Given 正在登录且 URL 弹框被关闭，When 登录流程继续，Then 必须立即取消当前登录任务，不应继续后台等待。
2. Given `auth.json` 先出现无效 UTF-8，随后变为有效 JSON，When 登录流程等待 auth 文件，Then 应判定成功而不是提前失败。

## 增补（2026-03-03：auth 目录事件联动改为文件夹监听 + Combine 聚合）
### 问题
1. 删除账号时，auth 目录常只上报 `renamed`，旧逻辑会把“已知账号文件 rename”直接忽略，导致卡片残留。
2. watcher 与 UI 侧同时做抖动抑制，容易出现联动不可预测，且难以定位“登录中不结束/卡片不消失”问题。

### 修复
1. `UsageMonitorFileWatcher` 取消内部 debounce，改为原始事件直通上抛（以“监听文件夹”为唯一来源）。
2. `ProviderUsageViewModel` 新增 `PassthroughSubject` + `debounce(300ms)` 聚合 auth 事件，统一通过 `enqueueCodexReload` 触发磁盘重载。
3. 取消 auth 事件抑制窗口模式：主链路不再注册/消费 suppression mark，仅保留“缓存写入中、账号刷新中”的运行时防重入过滤。
4. `CodexAuthEventPolicy.shouldIgnoreKnownAuthRename` 仅在 auth 目录外 rename（如移到 Trash）时才忽略；auth 目录内 rename 一律参与 reload。

### 验收（新增）
1. Given auth 目录内 burst 文件事件，When 300ms 内连续触发，Then 最终只执行一次磁盘重载。
2. Given 两次 auth 事件间隔超过 300ms，When 事件到达，Then 两次都应触发重载。
3. Given 删除账号仅上报 auth 目录内 `renamed`，When 事件到达，Then 不应被忽略且卡片会移除。

## 增补（2026-03-03：Codex 账号卡片时间行合并）
### 变更
1. 账号卡片中的“登录时间”和“同步时间”由两行改为同一行显示。
2. 登录时间格式统一为 `yyyy/MM/dd HH`（24 小时制）。
3. 同步时间改为相对时长：`同步于 xhxxmxxs 之前`（分钟、秒钟补零）。
4. 当任一字段缺失时，仅显示已有字段，不显示分隔符 ` · `。

### 验收（新增）
1. Given 同时有登录时间和同步时间，When 渲染账号卡片，Then 显示为 `登录于yyyy/MM/dd HH · 同步于 xhxxmxxs 之前`。
2. Given 仅有登录时间（或仅有同步时间），When 渲染账号卡片，Then 只显示单段文案且无 ` · `。
3. Given 同步时间晚于当前时间，When 计算相对时长，Then 结果钳制为 `0h00m00s`，不出现负数。

## 增补（2026-03-03：卡片时间文案可读性优化 + 右对齐）
### 变更
1. 保持单行展示，但同步时间由机械串改为可读规则：
   - `< 60s`：`刚刚同步`
   - `< 1h`：`同步于 Xm 前`
   - `< 24h`：`同步于 XhYm 前`（分钟为 0 时省略）
   - `>= 24h`：`同步于 MM/dd HH:mm`
2. 登录时间改为短格式：`登录 MM/dd HH:mm`。
3. 时间行文本改为卡片内右对齐显示。

### 验收（新增）
1. Given 同步刚完成（<60s），When 渲染卡片，Then 文案显示 `刚刚同步`，不出现 `0h00m00s`。
2. Given 同步时间在 1h~24h 内，When 渲染卡片，Then 文案显示小时/分钟相对时间（例如 `同步于 2小时5分 前`）。
3. Given 同步时间超过 24h，When 渲染卡片，Then 文案回退为绝对时间（`同步于 MM/dd HH:mm`）。
4. Given 该行可见，When 渲染卡片，Then 时间行右对齐。
