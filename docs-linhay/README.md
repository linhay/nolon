# docs-linhay

项目文档系统统一落在 `docs-linhay/`。

目录说明：
- `spaces/`：以 feature / topic / milestone 为单位的工作空间，入口固定为 `spaces/<space-key>/README.md`。
- `dev/`：技术方案、架构、接口、运行手册。
- `memory/`：主记忆与每日工作记录。
- `references/`：外部参考项目与归档资料。
- `scripts/`：文档系统相关脚本与说明。

维护约束：
- 需求先更新对应 `space` 的 `README.md`，再改代码。
- 技术方案放 `dev/`，并链接对应 `space`。
- 截图统一放 `spaces/<space-key>/screenshots/YYYYMMDD/<module>/`。
- 多 agent 辩论文档统一放 `spaces/<space-key>/debate/YYYYMMDD/<module>/`。
- 记忆写回统一落在 `memory/YYYY-MM-DD.md`。
- 新建 space 优先使用 `docs-linhay/scripts/create-space.sh <space-key>`。
- 提交前或治理规则调整后执行 `docs-linhay/scripts/check-docs.sh`。
- `references/` 视为外部资料镜像区，允许保留上游原始结构；上游文件命名不强制套用本仓规范。
