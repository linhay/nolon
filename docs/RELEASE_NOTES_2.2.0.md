## Highlights
- 修复带 CloudKit / Push capability 的 macOS 发布包在启动阶段可能直接崩溃的问题。
- 发布链路切换为 Xcode 官方 `archive + exportArchive` 签名导出，产物包含匹配的 `embedded.provisionprofile`。
- GitHub Actions release workflow 现在强校验 Developer ID provisioning profile，避免产出不可启动的假绿包。

## Fixes
- CloudKit 同步启动改为运行时 entitlement 预检 + 惰性 bootstrap，缺失签名能力时降级为不可用而不是启动即崩。
- `build-dmg.sh` 修复了 macOS 默认 Bash 兼容性、Xcode archive 架构参数冲突，以及 automatic signing / manual export profile 的组合问题。
- release 流程增加 Developer ID profile 的前置校验与安装步骤。
