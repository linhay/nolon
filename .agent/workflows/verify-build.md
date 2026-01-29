---
description: Verify Build
---

## COMMANDS
```bash
# Verify Build
./build.sh

# Build Release
xcodebuild -project nolon.xcodeproj -scheme nolon -configuration Release
```

## Troubleshooting
- 如果出现 SwiftPM / clang 缓存写入失败（例如对 `~/.cache`、`~/Library/Caches` 报 `Operation not permitted`），说明当前执行环境无法写入用户缓存目录；需要在允许写缓存的环境中重试（或为工具授予相应权限）。
