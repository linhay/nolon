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

## 匹配与判定规则
1. `matchAccount` 优先级：`email -> account.id -> OPENAI_API_KEY（完整值精确匹配）`，最后才回退 cleaned-json 全等。
2. provider auth 与 snapshot 冲突时使用评分选真值；同分时优先 provider。
3. `nolon.account.id`（UUID）不作为评分加分项，避免误压制 provider 结果。

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
