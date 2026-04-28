# GitHub Actions 自动发版（Sparkle）需求

日期：2026-03-21

## 背景
- 当前项目可在本地执行 `scripts/release.sh` 发版。
- 目标是后续改为通过 GitHub Actions 直接发版，减少本地手工步骤。
- 当前正式路径已切到 GitHub-hosted `macos-15` runner，不能再依赖某台固定 self-hosted 机器的本地状态。

## 范围
1. 新增可手动触发的 GitHub Workflow，用于执行现有发版脚本。
2. 保持本地发版能力不受影响。
3. 支持在 CI 中通过 GitHub Secrets 注入签名、公证、Sparkle 凭据，并保留 runner 本地 `release.env` 作为兼容回退。
4. 支持通过 `v*` tag push 自动触发发版。

## 验收场景（BDD）
1. Given 仓库管理员在 GitHub Actions 手动触发 release workflow 并输入版本号，When workflow 运行完成，Then 会完成构建、生成 appcast、创建/发布 GitHub Release 并上传 DMG 产物。
2. Given runner 存在 `~/.nolon/release-secrets/release.env`，When workflow 执行，Then 优先读取本地密钥文件（无该文件时回退 GitHub Secrets）。
3. Given workflow 提供 `SPARKLE_PRIVATE_KEY` Secret，When `scripts/release.sh` 进行 Sparkle 签名，Then 使用该密钥进行签名，不依赖 runner Keychain。
4. Given workflow 未提供 `SPARKLE_PRIVATE_KEY`，When `scripts/release.sh` 执行 Sparkle 签名，Then 回退使用 Sparkle keychain account（默认 `ed25519`）。
5. Given 本地开发者未设置 `SPARKLE_PRIVATE_KEY`，When 本地执行 `scripts/release.sh`，Then 仍使用现有 Keychain 读取逻辑，不改变原有行为。
6. Given workflow 缺失必要凭据，When 运行发版流程，Then 流程在对应步骤失败并输出可定位错误信息。
7. Given 仓库收到 `v2.1.6` 这类 tag push，When workflow 自动触发，Then release 脚本进入 CI tag 模式并跳过再次创建 tag。
8. Given workflow 运行在 GitHub-hosted runner，When 缺少 `SPARKLE_PRIVATE_KEY`、P12 对或公证凭据，Then workflow 在前置校验阶段直接失败，而不是等到签名或公证中途才报错。

## 配置约定
1. Workflow 文件：`.github/workflows/release.yml`
2. runner 本地密钥文件（可选但优先）：
   - `~/.nolon/release-secrets/release.env`
3. GitHub-hosted 必需 Secret：
   - `SIGNING_IDENTITY`
   - `SPARKLE_PRIVATE_KEY`
   - `MACOS_CERTIFICATE_P12_BASE64`
   - `MACOS_CERTIFICATE_P12_PASSWORD`
   - `NOTARY_PROFILE`
   - 或 `APPLE_ID` + `APPLE_APP_PASSWORD` + `TEAM_ID`
4. Tag 自动触发约定：
   - 触发：`push.tags = v*`
   - `CI_TAG_MODE=1`
   - `RELEASE_PUSH_BRANCH=main`
5. 可选 Secret（按签名/公证需求）：
   - `SPARKLE_KEYCHAIN_ACCOUNT`（默认 `ed25519`）

## 当前状态
- `.github/workflows/release.yml` 已切到 GitHub-hosted `macos-15` runner。
- workflow 会在 hosted 环境下前置校验 Sparkle、P12 和公证凭据，不满足时直接红灯。
- `scripts/validate-sparkle-key.sh` 已兼容 Sparkle 新旧两种私钥导出格式，避免因为历史导出格式差异误判 key 损坏。
- 仓库 Secrets 已回填为当前可用的一组发版凭据；后续 runner 本地 `release.env` 仅作为兼容回退，不再作为唯一配置源。
