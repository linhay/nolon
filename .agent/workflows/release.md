---
description: Release and distribute a new version of Nolon
---

1. 确保代码和依赖已更新。
   - 如果本次发布包含 submodule 指针更新，先提交 submodule 变更，保证工作区干净。
2. **准备更新日志**: 在发布前，建议创建并编写项目根目录下的 `docs/RELEASE_NOTES_<version>.md` 文件。
   - 脚本会自动抓取该文件内容作为 Sparkle 更新描述和 GitHub Release Notes。
   - 如果不创建此文件，脚本将自动根据 Git Commit 历史生成简版记录。
3. 运行发布脚本并指定版本号：

```bash
./scripts/release.sh <version>
```

示例：
```bash
./scripts/release.sh 0.1.0
```

该脚本将自动执行以下操作：
- 更新 Xcode 项目中的 `MARKETING_VERSION` 和构建号（基于时间戳）。
- 为 Apple Silicon (arm64) 和 Intel (x86_64) 进行构建和签名。
- 向 Apple 提交公证 (Notarize)。
- 更新 `docs/appcast.xml`（包含从 Markdown 抓取的详细描述）。
- 自动处理 Git 提交、打标签并推送至远程仓库。
- 创建 GitHub Release 并上传双架构 DMG 安装包。

## 失败处理
- 若脚本提示 `Tag already exists`：说明已存在同名 tag。
  - 若需重跑：先移动/删除本地与远程 tag，再重新执行脚本。
  - 若仅需补齐步骤：可手动完成 `appcast` 提交、`git push`、`gh release upload` 等操作。
