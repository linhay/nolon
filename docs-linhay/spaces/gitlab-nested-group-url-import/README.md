# GitLab 多级 Group URL 导入修复（2026-03-24）

## 背景
- 现有 Git URL 解析默认按 `owner/repo(/subpath)` 处理。
- 在 GitLab 多级 group 场景（如 `https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group`）中，错误把 `axure-skill-group` 当作子目录，导致实际拉取仓库变成 `f2e/axure-helper`。

## 目标
- 对 GitLab host（`host` 包含 `gitlab`）支持多级 namespace：
  - 仓库路径识别为“最后一段是 repo，前面全部是 owner/group 路径”。
- 保留已有能力：
  - `owner/repo/subpath` 简写仍按 GitHub 风格提取子路径。
  - GitLab `/-/tree/<branch>/<path>` 链接可提取 `subpath`。
- 认证策略增强：
  - `automatic` 策略下若以 `https anonymous` clone 失败，自动探测并回退 SSH clone。

## BDD 验收
1. Given 输入 `https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group`
   When 执行导入 URL 解析
   Then 规范化结果为 `https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group.git`
   And `subpath == nil`

2. Given 输入 `https://gitlab.dxy.net/f2e/axure-helper/axure-skill-group/-/tree/main/skills/web`
   When 提取子路径
   Then `subpath == "skills/web"`

3. Given 输入 `owner/repo/skills/foo`
   When 执行导入 URL 解析
   Then 规范化结果为 `https://github.com/owner/repo.git`
   And `subpath == "skills/foo"`

4. Given 输入 HTTPS GitLab 私仓 URL 且无 token
   And 首次 clone 返回认证失败
   When `automatic` 策略执行同步
   Then 自动尝试 SSH clone
   And 若 SSH 可用则同步成功

## 测试范围
- `RemoteGitRepositorySupportTests`
- `SkillsRepositoryFacadeTests`
- `NolonResourceKitTests`（`RepositoryDraftService`）
- `AddRepositoryViewModelTests`
- `RemoteRepositoryTests`
