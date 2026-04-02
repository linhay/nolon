# GitHub Actions 发版 Runbook（Sparkle）

日期：2026-03-21

## 目标
- 通过 GitHub Actions 手动触发完成 `nolon` 发版。
- 复用现有 `scripts/release.sh` 与 `scripts/build-dmg.sh`。

## Workflow
- 文件：`.github/workflows/release.yml`
- Runner：`self-hosted, macOS, ARM64`（当前为 `mini.lan` 上的 runner）
- 触发方式：
  - `workflow_dispatch`（手动）
  - `push.tags = v*`（自动）
- 输入参数：
  - `version`（必填）：例如 `2.1.6`
  - `changelog_file`（可选）：例如 `docs/RELEASE_NOTES_2.1.6.md`

## Secrets
1. 必需：
   - `SIGNING_IDENTITY`
2. 可选（按签名/公证需求）：
   - `SPARKLE_PRIVATE_KEY`（显式注入 Sparkle 私钥）
   - `SPARKLE_KEYCHAIN_ACCOUNT`（默认 `ed25519`，用于 keychain 回退）
   - `MACOS_CERTIFICATE_P12_BASE64`
   - `MACOS_CERTIFICATE_P12_PASSWORD`
   - `NOTARY_PROFILE`
   - `APPLE_ID`
   - `APPLE_APP_PASSWORD`
   - `TEAM_ID`

密钥来源优先级（从高到低）：
1. runner 本地文件：`~/.nolon/release-secrets/release.env`
2. GitHub Secrets（同名）

可用同步脚本（在仓库根目录执行）：
```bash
./scripts/sync-release-secrets-to-mini.sh mini.lan
```

脚本会读取当前 shell 与 `.env` 中的变量，并同步到 `mini.lan:~/.nolon/release-secrets/release.env`（权限 `600`）。

## 发版流程（CI）
1. checkout 代码并切到触发分支。
2. 读取 runner 本地 `release.env`（若不存在则回退到 GitHub Secrets）。
3. 配置 git bot 提交身份。
4. 校验版本号输入（仅手动触发）与必需 Secret（`SIGNING_IDENTITY`）。
5. 计算 release 参数：
   - 手动触发：`version` 来自输入
   - tag 触发：`version = GITHUB_REF_NAME` 去掉前缀 `v`，并设置 `CI_TAG_MODE=1`
6. 调用 `./scripts/release.sh <version> [changelog_file]`。
7. 脚本内完成：
   - 更新版本号与 build number
   - 构建双架构 DMG
   - Sparkle 签名并更新 `docs/appcast.xml` + 根目录 `appcast.xml`
   - 手动模式：提交、打 tag、推送
   - tag 模式：跳过创建 tag，仅同步 appcast commit 到 `main`
   - 创建/更新 GitHub Release 并上传 DMG
   - 等待 Pages appcast 可见后发布 Release

## 回滚/故障处理
1. 若 workflow 在发布前失败，先检查 `draft release`、tag 与提交是否已生成。
2. 若仅 appcast 同步失败：
   - 检查 GitHub Pages 状态
   - 待 appcast 可访问后手动执行：
     - `gh release edit <tag> --draft=false --latest`
3. 若 Sparkle 签名失败：
   - 若走 Secret 注入，校验 `SPARKLE_PRIVATE_KEY` 是否为完整私钥文本且无多余转义。
   - 若走 keychain 回退，确认 runner 上 `sign_update --account <account>` 可读取密钥（默认 `ed25519`）。
