# scripts

放文档系统相关脚本与使用说明。

规则：
- 脚本应附最小使用说明。
- 会修改文档树的脚本应说明输入、输出和回滚方式。

## build.sh
- 用途：本地默认门禁入口，执行 `nolon-app` 的 macOS 构建，并按配置继续跑测试。
- 默认包策略：`NO_SPM_UPDATE=1`，会给 `xcodebuild` 注入 `-skipPackageUpdates`，避免在依赖已解析的前提下因为 DNS / 弱网导致构建前置失败。
- 允许远端更新：显式传 `NO_SPM_UPDATE=0 ./build.sh`。
- 仅构建不测：`RUN_TESTS=0 ./build.sh`。
- 脚本 smoke test：`bash scripts/tests/build-smoke.sh`，通过 `XCODEBUILD_BIN` 注入 fake `xcodebuild` 验证参数拼装。
