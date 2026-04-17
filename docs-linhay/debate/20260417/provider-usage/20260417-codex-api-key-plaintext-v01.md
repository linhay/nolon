# codex-api-key-plaintext

**日期**：20260417
**模式**：合作型
**参与者**：Codex（主持人）
**总轮次**：1 / 60
**结束原因**：基于代码证据达成收敛

## 执行元数据
- 候选参与者：两名独立审查参与者（内部 explorer）
- 首轮实际启用：两名独立审查参与者
- 后续 active participants：无
- 淘汰参与者：两名独立审查参与者
- 不可用原因：启动后均返回 `502 Bad Gateway: unknown provider for model gpt-5.1-codex-mini`

## 辩论背景
> 用户继续要求把 Codex 配置编辑页里的 `API Key` 字段也从密文输入改成明文输入，并保持和此前 `Claude Credential` 一致的交互行为。

## 各轮观点记录

### 第 1 轮
**[Codex - 主持人]** 论点 → 引用:`nolon/Skills/Domain/Providers/Usage/Views/Codex/CodexConfigEditorSheet.swift:169-182` → 代码事实：`API Key` 字段标题与提示都位于该段，唯一导致密文展示的控件是 `SecureField("", text: stringBinding(\.apiKey))`，没有额外格式化或加密包装逻辑。→ 结论：本次最小正确改动就是把该处 `SecureField` 切换为 `TextField`。

**[Codex - 主持人]** 论点 → 引用:`nolonTests/CodexConfigEditorSheetSnapshotTests.swift:75-89` → 代码事实：新增 BDD 测试明确断言渲染结果中不存在 `NSSecureTextField`，且普通可编辑文本框中包含 `sk-live-12345678`。→ 结论：测试已经直接覆盖“取消密文展示”的需求验收点。

**[Codex - 主持人]** 论点 → 引用:`nolon/Skills/Domain/Providers/Usage/Views/Codex/CodexConfigEditorSheet.swift:176-181` → 代码事实：提示文案写明该值会在保存时写入 managed `auth.json`，当前改动仅影响编辑控件类型，不改变保存链路。→ 结论：本次属于 UI 展示策略调整，不涉及底层存储或写回协议变更。

## 最终结论与行动项

### 达成共识 / 裁定结论
- `CodexConfigEditorSheet` 的 `API Key` 明文化只需把 [CodexConfigEditorSheet.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Usage/Views/Codex/CodexConfigEditorSheet.swift#L181) 从 `SecureField` 改为 `TextField`。
- 回归测试以 [CodexConfigEditorSheetSnapshotTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/CodexConfigEditorSheetSnapshotTests.swift#L75) 的 BDD 用例为准，要求不存在 `NSSecureTextField` 且能看到明文 `API Key`。
- 安全加密与存储策略不是这次 debate 的范围，应作为独立安全增强议题讨论，不阻塞本次 UI 修复。

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 将 `CodexConfigEditorSheet` 的 `API Key` 输入控件切换为 `TextField` | Codex | 已完成 |
| 2 | 运行 `CodexConfigEditorSheetSnapshotTests` 验证明文展示 | Codex | 已完成 |

### 未解问题
- 是否需要把 `auth.json` / 其他 provider credential 的持久化安全策略统一升级，另开安全专题处理。
