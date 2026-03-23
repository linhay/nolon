# Leaderboard 模板运维 Runbook（2026-03-03）

## 日常检查
1. CI 审计是否通过（校验 + 快照构建）。
2. Pages 发布状态是否成功。
3. `latest.json` 是否可被网页读取。

## 常见故障
1. CI 报 `Snapshot drift detected`
   - 在本地执行 `python3 scripts/build_snapshot.py .`
   - 提交更新后的 `data/snapshots/latest.json`
2. 页面空白
   - 检查 `data/snapshots/latest.json` 是否存在且 JSON 合法
3. 排名异常
   - 检查 submission 中 `tool` 拼写与 `config/tool_aliases.json`

## 回滚
1. 回滚到上一个可用 commit。
2. 重新触发 Pages 发布。
3. 验证快照与页面恢复正常。
