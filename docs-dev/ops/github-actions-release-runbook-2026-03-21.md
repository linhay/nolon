# GitHub Actions 发版 Runbook（Sparkle）

日期：2026-03-21

## 目标
- 通过 GitHub Actions 手动触发完成 `nolon` 发版。
- 复用现有 `scripts/release.sh` 与 `scripts/build-dmg.sh`。

## Workflow
- 文件：`.github/workflows/release.yml`
- 触发方式：`workflow_dispatch`
- 输入参数：
  - `version`（必填）：例如 `2.1.6`
  - `changelog_file`（可选）：例如 `docs/RELEASE_NOTES_2.1.6.md`

## Secrets
1. 必需：
   - `SPARKLE_PRIVATE_KEY`：Sparkle Ed25519 私钥（用于 `sign_update --ed-key-file -`）
2. 可选（按签名/公证需求）：
   - `SIGNING_IDENTITY`
   - `NOTARY_PROFILE`
   - `APPLE_ID`
   - `APPLE_APP_PASSWORD`
   - `TEAM_ID`

## 发版流程（CI）
1. checkout 代码并切到触发分支。
2. 配置 git bot 提交身份。
3. 校验版本号输入与必需 Secret。
4. 调用 `./scripts/release.sh <version> [changelog_file]`。
5. 脚本内完成：
   - 更新版本号与 build number
   - 构建双架构 DMG
   - Sparkle 签名并更新 `docs/appcast.xml` + 根目录 `appcast.xml`
   - 提交、打 tag、推送
   - 创建/更新 GitHub Release 并上传 DMG
   - 等待 Pages appcast 可见后发布 Release

## 回滚/故障处理
1. 若 workflow 在发布前失败，先检查 `draft release`、tag 与提交是否已生成。
2. 若仅 appcast 同步失败：
   - 检查 GitHub Pages 状态
   - 待 appcast 可访问后手动执行：
     - `gh release edit <tag> --draft=false --latest`
3. 若 Sparkle 签名失败：
   - 校验 `SPARKLE_PRIVATE_KEY` 是否为完整私钥文本且无多余转义。
