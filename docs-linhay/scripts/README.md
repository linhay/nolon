# scripts

放文档系统相关脚本与使用说明。

规则：
- 脚本应附最小使用说明。
- 会修改文档树的脚本应说明输入、输出和回滚方式。

## create-space.sh
- 用途：创建一个标准 `space` 目录，生成 `README.md`、`plans/`、`screenshots/`、`debate/`。
- 用法：`bash docs-linhay/scripts/create-space.sh <space-key>`

## migrate-docs-to-spaces.sh
- 用途：把旧的 `features/`、`plans/`、`screenshots/`、`debate/` 迁到 `spaces/`。
- 输入：旧结构文档树。
- 输出：新结构 `docs-linhay/spaces/<space-key>/...`
- 风险：少量历史截图 / debate 若缺少 feature 引用，会走模块级回退映射；迁移前应确认当前工作树无未提交文档搬运冲突。

## check-docs.sh
- 用途：校验 `docs-linhay` 是否已经符合 spaces 新结构。
- 额外校验：`AGENTS.md` 中依赖的关键项目级 `gettokens-*` skills 是否实际存在。
- 用法：`bash docs-linhay/scripts/check-docs.sh`

## build.sh
- 用途：本地默认门禁入口，执行 `nolon-app` 的 macOS 构建，并按配置继续跑测试。
- 默认包策略：`NO_SPM_UPDATE=1`，会给 `xcodebuild` 注入 `-skipPackageUpdates`，避免在依赖已解析的前提下因为 DNS / 弱网导致构建前置失败。
- 允许远端更新：显式传 `NO_SPM_UPDATE=0 ./build.sh`。
- 仅构建不测：`RUN_TESTS=0 ./build.sh`。
- 脚本 smoke test：`bash scripts/tests/build-smoke.sh`，通过 `XCODEBUILD_BIN` 注入 fake `xcodebuild` 验证参数拼装。
