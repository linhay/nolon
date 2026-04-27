# docs-linhay spaces 迁移说明

## 背景
- `docs-linhay/` 之前同时保留 `features/`、`plans/`、`screenshots/`、`debate/` 四个顶层目录。
- 当前治理规则已经切到 `docs-linhay/spaces/<space-key>/`，旧结构继续保留会导致文档入口分裂、截图与计划脱节、引用路径持续漂移。

## 迁移目标
1. 需求文档迁到 `docs-linhay/spaces/<space-key>/README.md`。
2. 计划、截图、辩论文档跟随同一个 `space` 归档。
3. 根目录只保留 `spaces/`、`dev/`、`memory/`、`references/`、`scripts/`。
4. 后续新增 space 统一走 `docs-linhay/scripts/create-space.sh`，提交前用 `docs-linhay/scripts/check-docs.sh` 做自检。

## 迁移规则
1. `docs-linhay/features/<topic>[-YYYY-MM-DD].md` 迁到 `docs-linhay/spaces/<topic>/README.md`。
2. `docs-linhay/plans/*.md` 优先根据正文里引用的 feature 文档归属 space；找不到 feature 引用时按文件名关键词回退到稳定 topic space。
3. `docs-linhay/debate/<date>/<module>/*.md` 优先根据正文里引用的 feature 文档归属 space；找不到 feature 引用时按 module 做稳定回退映射。
4. `docs-linhay/screenshots/<date>/<module>/*` 按模块名和文件名关键词归档到对应 space 的 `screenshots/`。
5. 所有 markdown 内部引用在迁移后统一重写到新路径，包含仓库内绝对路径链接。

## 验证
- `bash scripts/tests/docs-space-governance-smoke.sh`
- `bash docs-linhay/scripts/check-docs.sh`

## 风险与边界
- 少数历史截图与 debate 只携带模块信息，没有明确 feature 引用，这部分依赖回退映射，后续若发现归档边界不理想，再按 space 粒度二次拆分。
- `docs-linhay/references/` 保持原样，不参与本轮结构迁移。
