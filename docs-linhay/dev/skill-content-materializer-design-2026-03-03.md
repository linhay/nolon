# SkillContentMaterializer 设计说明（2026-03-03）

## 方案
- 新增 `SkillContentMaterializer.copyMaterializingSymlinks(from:to:)`：
  1. 先执行目录复制。
  2. 递归遍历源目录，识别符号链接。
  3. 在目标目录同路径将链接替换为目标实体内容。

## 接入点
1. `SkillInstaller.installLocal(from:slug:to:)`
2. `NolonCoreCLIRunner.stageLocalSkillToCache(slug:sourcePath:)`

这样可同时覆盖 App 安装路径与 CLI 安装路径。

## 测试
- 在 `NolonResourceKitTests` 新增用例：构造 `.claude/skills/<slug>` 指向 `src/<slug>/scripts` 的相对链接，验证安装后 global skill 中 `scripts` 不再是符号链接且 `search.py` 存在。
