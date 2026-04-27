# Resource Center GitHub Skill 安装修复执行计划

日期：2026-04-14

## 背景
- `scale` 这类 GitHub skill 在部分 provider 目录布局下会安装失败。
- 用户感知到的表象是“安装中”持续很久，之后才报错，导致问题定位偏向 UI timeout，而不是安装落地。
- 当前 debate 已经收敛，代码修复与定向测试也已完成，需要一份可执行计划用于后续验收、回归和上线收口。

## 目标
1. 确保 GitHub/local repo skill 在 linked-root 与 parent-linked-root 布局下都能正确落地为实体目录。
2. 确保 Resource Center 所有相关安装入口都能即时结束失败态 pending，并展示真实错误。
3. 用定向测试和手工 smoke checklist 锁住回归。
4. 将结论、风险、后续观测点沉淀到 debate / memory / qmd。

## BDD 场景
1. `Given provider skills root resolves to global skills root when installing scale then ~/.nolon/skills/scale stays as a real directory`
2. `Given provider parent path resolves to global skills root when installing scale then ~/.nolon/skills/scale still stays as a real directory`
3. `Given install throws from Resource Center when user starts install then pending is cleared immediately and real error is surfaced`
4. `Given no rich localized error is available when install fails then UI falls back to retry hint instead of hanging`

## 执行步骤
1. 代码核对
- 确认 `SkillInstaller` 与 `ProviderSkillMaintenanceService` 使用相同的真实路径解析口径。
- 确认 Resource Center 主列表、workflow detail、MCP detail、remote skill detail window 都统一走 `begin*Install(...)`。
2. 自动验证
- 执行定向测试：
  - `nolonTests/SkillInstallerTests`
  - `nolonTests/ResourceCatalogGridViewInstallStateTests`
3. 手工 smoke
- 从 GitHub 仓库安装 `scale`。
- 验证全局落点 `~/.nolon/skills/scale` 是实体目录。
- 人工构造失败场景，确认界面即时结束“安装中”并显示真实错误。
4. 文档收口
- 更新 feature / dev / debate / memory。
- 执行 `qmd update` 与 `qmd embed`。

## 验证命令
- 自动测试：
```bash
xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/SkillInstallerTests -only-testing:nolonTests/ResourceCatalogGridViewInstallStateTests
```
- 路径核验：
```bash
ls -l ~/.nolon/skills
```

## 完成定义
1. 定向测试通过。
2. GitHub `scale` 安装 smoke 不再复现“长时间安装中再失败”。
3. `~/.nolon/skills/scale` 验证为实体目录。
4. 相关文档与记忆已写回，`qmd` 可检索。

## 非目标
- 本轮不重做 Resource Center 安装进度 UI。
- 本轮不引入更复杂的路径大小写/跨卷标准化策略。
- 本轮不对超大仓库复制性能做架构级优化，只保留观测点。
