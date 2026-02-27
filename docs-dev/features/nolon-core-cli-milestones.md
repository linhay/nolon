# Nolon 核心能力 CLI 化里程碑（macOS + Linux）

## 目标

将 Nolon 核心能力从 App 内部实现下沉为可复用的 CLI/SDK 能力，App 仅负责编排与展示。

平台范围：
- 默认支持：macOS、Linux
- App（SwiftUI）为编排端；核心能力沉淀在 `libs/Providers`（后续可独立 CLI 包装）

## 业务域划分

1. Repository 域（远程仓库）
- 仓库源识别与规范化（shorthand / HTTPS / SSH）
- 拉取与更新（clone / pull）
- 资源发现（skills/workflows/mcp）

2. Skill Spec 域（规范解析）
- `SKILL.md` frontmatter 标准字段解析
- 兼容旧格式与告警策略

3. Runtime Provider 域（Codex 等 Provider）
- CLI 命令封装
- app-server JSON-RPC 封装
- 运行时账户与会话能力

4. Orchestration 域（App）
- 组合调用 SDK 能力
- 不持有重复解析和 Git 细节逻辑

## 里程碑

### M1（已完成）标准解析下沉
- 完成项：
  - `ProviderCatalog.SkillSpecificationParser`
  - `SkillParser` 委托库层解析（App 去重）
  - 测试：`SkillSpecificationParserTests` / `SkillParserSpecificationTests`
  - 第二轮增强：未知顶层字段告警、空必填字段告警、`allowed-tools` 兼容解析（逗号分隔/混合数组）
- 验收：
  - 标准字段解析稳定
  - 旧技能导入不回归

### M2（已完成）远程仓库识别/发现下沉
- 完成项：
  - `RemoteGitRepositorySupport` 统一 URL 规范化、路径建议、目录发现
  - 新增 `SkillsRepositoryFacade` 作为 SDK 统一入口
  - App `GitRepository` 改为调用 façade
- 验收：
  - `agent-skills` 风格目录可发现
  - `skillNames` 可读取 frontmatter `name`

### M3（已完成）CLI Facade 收口（SDK -> CLI 命令面）
- 完成项：
  - 新增 `nolon-core` 可执行命令面（`skills repo plan/sync`、`skills discover`、`skills parse`、`resources discover`）
  - 新增 `NolonCoreCLIKit`，CLI 与 SDK 共用一套仓库能力
  - JSON 输出协议落地（成功 stdout / 失败 stderr，统一退出码）
- 验收：
  - 同一输入在 macOS/Linux 路径语义一致
  - CLI 与 SDK 输出结构一致
  - 命令解析与执行单测已覆盖

### M4（进行中）端到端编排收口
- 计划项：
  - App 全面迁移到 SDK/CLI façade
  - 删除 App 层重复 Git/解析实现
  - 补齐回归矩阵（功能 + 兼容）
- 已完成（第 1 轮）：
  - 新增 façade 仓库身份语义：`parseRepositoryIdentity` / `detectGitProvider`
  - App `RemoteRepository.extractRepoName/extractRepoFullName/detectProvider` 改为委托 façade
  - 补齐 Providers + App 对齐回归测试
- 已完成（第 2 轮）：
  - 仓库同步策略下沉（`pullStrategy` / `credentialStrategy`）
  - `sync` 结果补充 `defaultBranch` 与 `credentialMode`
  - `token-only` 无 token 错误语义收口为 `accessTokenRequired`
  - CLI `skills repo sync` 接入 `--pull-strategy` / `--credential-strategy`
- 已完成（第 3 轮）：
  - 新增 `skills repo preflight`，支持在 plan 阶段预检同步策略
  - façade 新增 `preflightSync`，统一输出 `requiresAccessToken/credentialMode/warnings`
  - CLI/SDK/app 边界保持：策略判定与预检逻辑仅在 `libs/Providers`
- 已完成（第 4 轮）：
  - `skills repo plan` 升级为输出 `plan + preflight`
  - 形成稳定三段协议：`plan -> preflight -> sync`
- 验收：
  - App 仅保留编排与 UI
  - 核心能力可离线通过 CLI 独立验证

## DoD（阶段）

1. BDD 场景齐备并可追踪。
2. 对应 TDD 测试存在且通过。
3. `docs-dev/features` 与 `docs-dev/dev` 同步更新。
4. 关键决策写入 `memory/YYYY-MM-DD.md` 并 `qmd update && qmd embed`。
