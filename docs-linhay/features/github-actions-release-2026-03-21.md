# GitHub Actions 自动发版（Sparkle）需求

日期：2026-03-21

## 背景
- 当前项目可在本地执行 `scripts/release.sh` 发版。
- 目标是后续改为通过 GitHub Actions 直接发版，减少本地手工步骤。

## 范围
1. 新增可手动触发的 GitHub Workflow，用于执行现有发版脚本。
2. 保持本地发版能力不受影响。
3. 支持在 CI 中通过 Secret 注入 Sparkle 私钥完成签名。
4. 支持通过 `v*` tag push 自动触发发版。

## 验收场景（BDD）
1. Given 仓库管理员在 GitHub Actions 手动触发 release workflow 并输入版本号，When workflow 运行完成，Then 会完成构建、生成 appcast、创建/发布 GitHub Release 并上传 DMG 产物。
2. Given workflow 提供 `SPARKLE_PRIVATE_KEY` Secret，When `scripts/release.sh` 进行 Sparkle 签名，Then 使用该 Secret 进行签名，不依赖 runner Keychain。
3. Given 本地开发者未设置 `SPARKLE_PRIVATE_KEY`，When 本地执行 `scripts/release.sh`，Then 仍使用现有 Keychain 读取逻辑，不改变原有行为。
4. Given workflow 缺失必要凭据，When 运行发版流程，Then 流程在对应步骤失败并输出可定位错误信息。
5. Given 仓库收到 `v2.1.6` 这类 tag push，When workflow 自动触发，Then release 脚本进入 CI tag 模式并跳过再次创建 tag。

## 配置约定
1. Workflow 文件：`.github/workflows/release.yml`
2. 必需 Secret：
   - `SPARKLE_PRIVATE_KEY`
3. Tag 自动触发约定：
   - 触发：`push.tags = v*`
   - `CI_TAG_MODE=1`
   - `RELEASE_PUSH_BRANCH=main`
4. 可选 Secret（按签名/公证需求）：
   - `SIGNING_IDENTITY`
   - `NOTARY_PROFILE`
   - `APPLE_ID`
   - `APPLE_APP_PASSWORD`
   - `TEAM_ID`
