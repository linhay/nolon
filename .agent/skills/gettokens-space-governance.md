# Skill: gettokens-space-governance

用于管理 `docs-linhay/spaces/` 下的正式工作空间材料，避免 `space` 命名、README、截图、debate 归档失控。

## trigger
- 新建或调整 `space`。
- 归档截图、计划、debate、README。
- 用户要求把需求或阶段工作正式落到文档系统。

## workflow
1. 先确定 `space-key`
   - 优先使用 `<YYYYMMDD>-<topic>` 或稳定英文功能名。
   - 禁止中文、空格、`latest`、`final`。
2. 创建或复用标准目录
   - 优先执行 `bash docs-linhay/scripts/create-space.sh <space-key>`。
   - 标准结构固定为 `README.md`、`plans/`、`screenshots/`、`debate/`。
3. 归档规则
   - 需求背景、目标、范围、验收标准写在 `README.md`。
   - 执行计划写在 `plans/`。
   - 截图放 `screenshots/YYYYMMDD/<module>/`。
   - 多 agent 辩论放 `debate/YYYYMMDD/<module>/`。
4. 回链要求
   - `dev/` 技术方案要链接相关 `space`。
   - 收尾说明里要给出本轮涉及的 `space` 路径。

## do
- 对需求变更先落 `space`，再改代码。
- 保持同一主题材料聚合在同一个 `space` 下。

## dont
- 不要把需求文档直接散落到 `docs-linhay/dev/`。
- 不要把截图和 debate 放回根目录旧路径。

## validation
- `bash docs-linhay/scripts/check-docs.sh` 通过。
- 所有新增 `space` 都含有四个标准子结构。
