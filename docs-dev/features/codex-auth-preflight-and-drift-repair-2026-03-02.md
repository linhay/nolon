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

## 匹配与判定规则
1. `matchAccount` 优先级：`email -> account.id -> OPENAI_API_KEY`，最后才回退 cleaned-json 全等。
2. provider auth 与 snapshot 冲突时使用评分选真值；同分时优先 provider。
3. `nolon.account.id`（UUID）不作为评分加分项，避免误压制 provider 结果。

## 备份与恢复
1. 仅备份 active 快照。
2. 触发点：进入用量页（load）、手动刷新、漂移修复流程。
3. 周期：5 分钟最小间隔。
4. 保留：最多 10 份，且清理 30 天前备份。

## 验收（BDD）
1. Given detached provider auth 与匹配快照，When preflight，Then 以 provider 内容覆盖快照并重建软链。
2. Given detached provider auth 无匹配快照，When preflight，Then 创建新快照并重建软链。
3. Given provider auth 损坏而快照健康，When preflight，Then 保持快照为真值并重建软链。
4. Given active 快照被外部改写，When preflight，Then 恢复 active 并保留漂移账号数据到新/匹配快照。
