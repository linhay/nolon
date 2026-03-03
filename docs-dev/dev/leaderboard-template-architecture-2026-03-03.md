# Leaderboard 模板架构说明（2026-03-03）

## 目录
- `projects/leaderboard-template/web/`：静态页面
- `projects/leaderboard-template/data/submissions/`：原始提交
- `projects/leaderboard-template/data/snapshots/latest.json`：聚合快照
- `projects/leaderboard-template/scripts/`：校验/聚合/打包

## 数据流
1. 客户端生成 submission JSON 并发起 PR/MR。
2. CI 执行 `validate_all_submissions.py`。
3. CI 执行 `build_snapshot.py` 生成快照。
4. CI 校验 `latest.json` 是否与提交一致（避免未更新快照）。
5. main 分支发布站点（GitHub Pages / GitLab Pages）。

## 关键规则
- 用户名：`^[A-Za-z0-9_]{3,20}$`
- 去重键：`userId + date + tool`
- 同键冲突：使用 `submittedAt` 更新更晚的记录
- 异常值：`totalTokens > 100_000_000` 不参与榜单

## 榜单维度
- `overall`: daily / 7d / rising
- `byTool.<tool>`: daily / 7d / rising
