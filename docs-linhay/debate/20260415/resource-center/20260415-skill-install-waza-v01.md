# skill-install-waza

**日期**：20260415
**模式**：合作型
**参与者**：Gemini（福尔摩斯）/ Codex（主持）/ Codex Explorer（Nietzsche）
**总轮次**：2 / 60
**结束原因**：Gemini 与 Codex 侧完成证据收敛；Claude CLI 因 `401 Invalid API key` 未能参与有效轮次

## 辩论背景

用户反馈 `tw93/Waza` 仓库下的 skill 在 App 中会“一直显示安装中，然后报错”。要求先用 `debate` 流程调查，不允许凭空推断。

已先用 CLI 复现分流：

- `remote sync --source tw93/Waza` 成功，仓库检测到 `skills` 目录与 8 个 skill。
- `skills add learn` 成功。
- `skills add waza` 失败，返回 `skill_not_found`。
- `remote sync-install --slug learn` 成功。

因此先排除“CLI 安装器整体坏掉”。

## 各轮观点记录

### 第 1 轮

**[Gemini - 福尔摩斯]**

- 论点：App 安装时并没有把 repo 名直接传给安装器，而是走 `RemoteSkill.slug` / `localPath`。
  引用：`nolon/Skills/Domain/App/Core/MainSplitView.swift:341`、`libs/Providers/Sources/NolonResourceKit/Infrastructure/RemoteInstallOrchestrator.swift:35`、`libs/Providers/Sources/NolonResourceKit/Infrastructure/LocalFolderRepository.swift:120`
- 论点：UI 的“安装中”状态依赖 `installedSlugs` 的异步回写；45 秒等不到才会超时。
  引用：`nolon/Skills/Domain/Resources/Views/ResourceCenter/ResourceCatalogGridView.swift:796`
- 初始假设：更像“状态误报”而不是安装器失败。

**[Codex - 主持复核]**

- 论点：Gemini 关于“直接从 Git clone 路径做 symlink 导致 prefix 不匹配”的中间推断不成立。
  引用：`libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift:223`
  代码事实：`installLocal` 会先把 skill 复制到 `~/.nolon/skills/<slug>`，再安装到 provider。
- 论点：`tw93/Waza` 仓库目录下没有 symlink 或异常层级，`copyMaterializingSymlinks` 不太可能因为仓库结构本身卡住。
  引用：`libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillContentMaterializer.swift:7`
  现场事实：`find ~/.nolon/repositories/github.com/tw93@Waza/skills -type l` 无输出。

### 第 2 轮

**[Codex Explorer - Nietzsche]**

- 论点：`installLocal` 是同步完成后才返回，异步尾巴只有 lock file 写入；因此“安装没完成就提前返回”不成立。
  引用：`libs/Providers/Sources/NolonResourceKit/Infrastructure/RemoteInstallOrchestrator.swift:41`、`libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift:223`
- 论点：Git 根目录 skill 的 slug 会取本地扫描目录 basename，不会从 `SKILL.md` 自定义覆盖。
  引用：`libs/Providers/Sources/NolonResourceKit/Infrastructure/LocalFolderRepository.swift:90`、`libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillParser.swift:54`
- 初始假设：怀疑 `targetProvider` 与安装后刷新使用的 provider 不一致。

**[Codex - 交叉质疑后裁定]**

- 驳回点：`targetProvider` 不一致这条不足以解释当前现象。
  引用：`libs/NolonUIFoundation/Sources/NolonUIFoundation/ResourceInstallSelectionViewModel.swift:26`
  代码事实：当 `targetProviderID` 存在时，卡片点击安装会直接安装到这个固定 provider，不会弹出切换选择器。
- 现场事实：当前用户环境中存在异常全局 skill 形态：
  - `~/.nolon/skills/learn -> /tmp/nolon-home-waza/skills/learn`
  - `~/.nolon/skills/design -> /Users/linhey/.nolon/skills/design`（自指 symlink）
  - `~/.nolon/skills/check` 是正常目录
- 论点：这说明 Waza 相关 skill 的全局缓存状态已经被污染，至少存在历史安装留下的异常 symlink。
  引用：`libs/Providers/Sources/NolonResourceKit/Infrastructure/SkillInstaller.swift:520`
  代码事实：installed 判定依赖 symlink 目标是否落在当前 `nolonManager.skillsPath` 下，污染状态会直接影响 UI 对“已安装”的识别。
- 旁证：测试明确要求 linked global root 场景应 materialize 为真实目录，而不是在全局 cache 留下 symlink。
  引用：`nolonTests/SkillInstallerTests.swift:147`、`libs/Providers/Tests/ProvidersTests/NolonSkillsRepositoryServiceTests.swift:145`

## 最终结论与行动项

### 达成共识 / 裁定结论

- `tw93/Waza` 这次问题不是 CLI 安装器坏了，也不是 App 把 repo 名 `waza` 直接当成 skill slug 去装。
- App 当前安装链路是：`RemoteSkill.slug/localPath -> installLocal -> 写入 ~/.nolon/skills -> 再装 provider`。
- UI “一直安装中然后报错”是一个二级症状，根因在于安装后 `installedSlugs` 没有按预期回写。
- 当前用户环境里已经存在 Waza skill 的异常全局 symlink 状态，这是实锤现场，不是推断；它足以污染 installed 状态识别。
- `targetProvider` 与用户改选 provider 的假设在当前代码下不成立，因为有固定 provider 时不会弹选择器。

### 行动项

| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 为 `installLocal -> refreshInstalledSkills -> scanProvider/listSkills` 增加链路日志，打印 `slug/provider/globalPath/providerPath/scanResult` | Codex | 下一个修复提交 |
| 2 | 增加回归测试：污染态全局 symlink skill 不应导致 Git skill 安装后 UI timeout | Codex | 下一个修复提交 |
| 3 | 复核并修复 Waza 历史异常项（至少 `learn` / `design`）对当前 UI 状态识别的影响 | Codex | 下一个修复提交 |

### 未解问题

- 这些异常全局 symlink 是由旧版本 App、CLI 还是某次带临时 `NOLON_HOME` 的安装流程写入的，还没有完全钉死。
- 还缺一次带日志的 App 侧最小复现，来确认 timeout 是由污染态触发，还是还存在另一条未覆盖的 installed 状态分支。
