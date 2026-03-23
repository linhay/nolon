# Release 2.1.3（2026-03-12）

## 范围
- 修复 Clawhub 远程列表在 HTTP 429 时直接失败的问题，补齐同 host 重试。
- 修复 Gemini 用量页当前激活账号重复展示的问题。

## 验证
- `swift test --package-path libs/Providers --filter SkillsRepositoryFacadeTests`
- `xcodebuild test -quiet -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexUsageTabPresentationTests`
- `./build.sh`

## 发布说明
- 版本号计划从 `2.1.2` 提升到 `2.1.3`。
- build number 由发布脚本按发布时间生成。
- Sparkle appcast 与 GitHub Release 由 `scripts/release.sh` 更新。
