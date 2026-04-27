# Claude Credential 明文展示

**日期**：20260417
**模式**：合作型
**参与者**：Gemini（福尔摩斯）、Claude Code（波洛，首轮淘汰）、Copilot（外援）
**主持人**：Codex
**总轮次**：2 / 60
**结束原因**：全员共识

## 执行元数据
- 候选参与者：Gemini、Claude Code、Copilot
- 首轮实际启用：Gemini、Claude Code
- 后续 active participants：Gemini、Copilot
- 淘汰参与者：Claude Code
- 不可用原因：
  - Claude Code：首轮执行返回默认模型不可访问，报错 `The selected model ... may not exist or you may not have access to it`

## 辩论背景
> 用户要求将 Claude 账号编辑页中 `Credential` 字段从“密文展示”改为“明文展示”。争论点不在于是否接受需求，而在于这次实现应只修改展示层，还是要连同草稿、JSON 预览、持久化、激活写回乃至存储加密一起重构。

## 各轮观点记录

### 第 1 轮
**[Gemini - 福尔摩斯]**
- 代码事实：`nolon/Skills/Domain/Providers/Usage/Views/Claude/ClaudeAccountEditorSheet.swift:243` 使用 `SecureField("", text: stringBinding(\.credentialValue))`
- 代码事实：`nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageSubViewModels.swift:431-448` 会把 `trimmedCredentialValue` 直接写入 `settingsPreviewObject.env`
- 代码事实：`libs/Providers/Sources/ProviderUsage/ClaudeAccount.swift:24-25,171,220` 中 `credentialValue` 是普通 `String`，Codable 编解码没有任何加解密逻辑
- 代码事实：`libs/Providers/Sources/ProviderUsage/ClaudeAccountManager.swift:123,148` 保存链路只做 trim，随后原样落盘
- 结论：当前“密文”只来自 `SecureField` 的展示行为；最小修复是改为 `TextField`，并补一条针对明文输入控件的回归测试。

**[Claude Code - 波洛]**
- 首轮未产出有效观点。
- 淘汰原因：CLI 默认模型不可用，无法完成带代码引用的回答。

**[Copilot - 外援]**
- 代码事实：`nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageSubViewModels.swift:592-597,681-685` 编辑草稿读取和保存都直接传递 `credentialValue`
- 代码事实：`libs/Providers/Sources/ProviderUsage/ClaudeAccount.swift:87-91` 的 `CryptoKit` 仅用于 `credentialFingerprint`，不参与 `credentialValue` 存储
- 结论：从当前需求看，UI 层可以单独修；但存储层仍是明文，属于独立安全议题，需要留痕而不是在本轮顺手扩改

### 第 2 轮
**[Gemini - 福尔摩斯]**
- 文档事实：`docs-linhay/spaces/claude-account-editor-page/README.md` 已把本特性的目标限定为编辑页能力与现有落盘/写回链路
- 结论：在不改变既有持久化架构的前提下，本次需求可定义为“UI 明文展示修复 + 测试补齐”，存储加密应拆为后续议题

**[Copilot - 外援]**
- 文档事实：`docs-linhay/spaces/claude-account-editor-page/README.md` 没有把加密存储列入目标、非目标或测试要求
- 结论：同意将 `SecureField -> TextField` 作为本轮交付边界；存储加密单列后续 work item，不阻塞当前实现

## 最终结论与行动项

### 达成共识 / 裁定结论
- 当前需求命中的是展示层问题，不是数据链路问题。
- `Credential` 字段改为明文输入的最小实现是：将 `ClaudeAccountEditorSheet` 中的 `SecureField` 替换为 `TextField`。
- 必须补一条回归测试，锁定“编辑态不存在 `NSSecureTextField`，且明文 credential 出现在普通可编辑文本框中”。
- 存储加密不是本次 UI 修复前置条件，但应作为后续安全增强议题记录。

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 将 Claude 编辑页 `Credential` 输入从 `SecureField` 改为 `TextField` | Codex | 本轮 |
| 2 | 为明文输入补充 BDD 回归测试 | Codex | 本轮 |
| 3 | 将“Claude credential 存储加密”登记为独立安全增强议题 | 后续 | 待排期 |

### 未解问题
- 账号凭据目前仍以明文形式流经 SQLite 与 `settings.json` 写回链路；若后续要提升安全性，需要单独设计迁移与兼容策略。
