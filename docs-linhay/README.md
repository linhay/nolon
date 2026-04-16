# docs-linhay

项目文档系统统一落在 `docs-linhay/`。

目录说明：
- `dev/`：技术方案、架构、接口、运行手册。
- `features/`：需求、功能规格、产品语义。
- `plans/`：迭代计划、执行计划、里程碑拆解。
- `memory/`：主记忆与每日工作记录。
- `references/`：外部参考项目与归档资料。
- `screenshots/`：按日期和模块归档的截图。
- `debate/`：多 agent 辩论文档。
- `scripts/`：文档系统相关脚本与说明。

维护约束：
- 需求先更新 `features/`，再改代码。
- 技术方案放 `dev/`，并链接对应 feature 文档。
- 截图统一放 `screenshots/YYYYMMDD/<module>/`。
- 记忆写回统一落在 `memory/YYYY-MM-DD.md`。
- `references/` 视为外部资料镜像区，允许保留上游原始结构；上游文件命名不强制套用本仓规范。
