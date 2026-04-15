# copilot-usage-integration

**日期**：20260415
**模式**：合作型
**参与者**：Gemini（福尔摩斯）/ Claude（波洛，CLI 本轮未产出有效结果）/ Codex（主持）
**总轮次**：2 / 60
**结束原因**：第 2 轮形成可执行共识

## 辩论背景
> 目标是判断：参考项目里已经存在的 GitHub Copilot usage 拉取能力，应该如何接入当前 Nolon 框架。争议点不在底层 fetcher，而在主应用层是否应该同时开放 Provider Usage 页面与 Accounts 总览入口。

## 各轮观点记录

### 第 1 轮
**[Gemini - 福尔摩斯]**
- 论点：Copilot usage 底层链路已经打通，主断点在 UI 准入配置。 → 引用：[libs/Providers/Sources/ProviderUsage/ProviderUsageRegistry.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/ProviderUsageRegistry.swift#L5) → `ProviderUsageRegistry` 已将 `.copilot` 映射到 `CopilotUsageDescriptor()`；`CopilotUsageDescriptor` 又直接读取 `context.token` 或 `COPILOT_API_TOKEN` 并调用 `CopilotUsageFetcher`。 → 结论：不需要新建 provider usage 协议或 fetcher。
- 论点：Copilot 详情页当前不会出现 Usage tab，是模板配置造成的。 → 引用：[libs/Providers/Sources/ProviderCatalog/ProviderTemplateEmbeddedJSON.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderCatalog/ProviderTemplateEmbeddedJSON.swift#L105) → `copilot` 仅配置了 `vendorTabs: ["agents"]`，且 `supportsAccounts: false`。 → 结论：如果只想开放 provider 内部的 usage 页，改模板配置即可。
- 论点：第 1 轮初始建议倾向同时开启 `vendorTabs += usage` 与 `supportsAccounts = true`。 → 引用：[libs/Providers/Sources/NolonResourceKit/Models/ProviderPresentationSections.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Models/ProviderPresentationSections.swift#L86) → 账号总览页依赖 `template.supportsAccounts`。 → 结论：若希望 Copilot 进入总览页，必须改该开关。

**[Codex - 主持复核]**
- 论点：Accounts 总览与 Usage 页在当前架构里是两个独立入口，不应绑成一批决策。 → 引用：[nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageRootViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageRootViewModel.swift#L118) → `loadAccounts()` 与 `loadUsage()` 已拆分，`loadPage()` 只是顺序组合。 → 结论：开放 Usage tab 不等于必须进入 Accounts 总览。
- 论点：即便 Copilot 进入 Accounts 总览，技术上也不是卡在映射层。 → 引用：[nolon/Skills/Domain/Accounts/ViewModels/NolonAccountsViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Accounts/ViewModels/NolonAccountsViewModel.swift#L444) → `mapUsageProvider(for:)` 对普通 template 直接按 `UsageProvider(rawValue: templateId)` 映射，`copilot` 可映射成功。 → 结论：真正的约束是产品入口，而不是代码映射能力。

### 第 2 轮
**[Codex - 主持质疑]**
- 论点：Copilot 当前没有独立账号模型，也没有多账号管理路径，不应因为 usage fetcher 已存在就自动抬升为“账号型 provider”。 → 引用：[nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageAccountsViewModel+CardModels.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageAccountsViewModel+CardModels.swift#L149) → 只有 `.claude` 与 `.gemini/.antigravity` 有专门账号卡片分支，`default` 分支没有额外账号动作；同时统一卡片 `default` 直接返回空列表。 → 结论：Copilot 目前更像“单 provider usage”，不是“账号管理 provider”。
- 论点：Accounts 总览虽然能拿到 usage outcome，但它本质上只是通用摘要，不会自然补出 Copilot 专属账号语义。 → 引用：[nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift#L509) → 对非 codex provider，`load()` 会直接 `usageMonitor.fetchOutcomes`；没有 Copilot 专属账号态装配。 → 结论：`supportsAccounts = true` 会把 Copilot 放进总览，但不会同时得到有意义的账号管理体验。

**[Gemini - 福尔摩斯，修正后]**
- 论点：应先解锁 Usage tab，而不是同批改 `supportsAccounts`。 → 引用：[nolon/Skills/Domain/Providers/Views/ProviderContentTabView.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/ProviderContentTabView.swift#L185) → provider 详情页的 tab 直接由 `vendorTabs` 注入；只要把 `usage` 放入 Copilot template，就能出现 Usage 页面。 → 结论：第一阶段最小改动是 `vendorTabs: ["agents", "usage"]`。
- 论点：`supportsAccounts` 应延后到确有账号管理诉求时再开。 → 引用：[libs/Providers/Sources/NolonResourceKit/Models/ProviderPresentationSections.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Models/ProviderPresentationSections.swift#L86) → 账号总览页准入只由 `supportsAccounts` 控制。 → 结论：现在同步打开，只会把 Copilot 提前暴露到 Accounts 总览，而不会同步带来更完整的账号能力。

## 最终结论与行动项

### 达成共识 / 裁定结论
- 共识 1：`libs/Providers` 层的 Copilot usage 抓取链路已经具备接入条件，不需要新增 fetcher 或新协议。证据：
  [libs/Providers/Sources/ProviderUsage/Descriptors/CopilotUsageDescriptor.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/Descriptors/CopilotUsageDescriptor.swift#L11)
  [libs/Providers/Sources/Providers/Copilot/CopilotUsageFetcher.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Copilot/CopilotUsageFetcher.swift#L20)
- 共识 2：第一阶段最小可行接入路径是只修改 Copilot template，把 `usage` 加到 `vendorTabs`，先开放 provider 详情页里的 Usage 页面。证据：
  [libs/Providers/Sources/ProviderCatalog/ProviderTemplateEmbeddedJSON.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderCatalog/ProviderTemplateEmbeddedJSON.swift#L105)
  [nolon/Skills/Domain/Providers/Views/ProviderContentTabView.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/ProviderContentTabView.swift#L185)
- 共识 3：`supportsAccounts = true` 不应与 `vendorTabs += usage` 同批落地，应作为第二阶段产品决策。原因是当前 Copilot 没有独立账号管理模型，进入 Accounts 总览只会获得通用 usage 摘要，不会自然形成完整账号体验。证据：
  [libs/Providers/Sources/NolonResourceKit/Models/ProviderPresentationSections.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/NolonResourceKit/Models/ProviderPresentationSections.swift#L86)
  [nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageAccountsViewModel+CardModels.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageAccountsViewModel+CardModels.swift#L149)
  [nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift#L509)

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 在 Copilot template 中新增 `usage` vendor tab，验证详情页能进入 Usage 页面 | Codex / 开发者 | 下一个实现回合 |
| 2 | 为该改动补 provider tab / usage 可见性测试 | Codex / 开发者 | 同一实现回合 |
| 3 | 单独评估 Copilot 是否值得进入 Accounts 总览页，以及需要什么账号语义 | 产品/开发 | 第二阶段 |

### 未解问题
- `COPILOT_API_TOKEN` 的来源最终是只走环境变量，还是需要像 codex token account 一样做 UI 配置入口。
- Copilot 的 usage 文案是否需要针对 `premium/chat` 做专门命名，而不是沿用通用 usage window 文本。

## 实施结果
- 已按“阶段一只开放 provider 详情页 usage，不进入 Accounts 总览”的裁定完成第一段闭环：`cli -> sdk -> app`。
- CLI 已新增 `nolon copilot auth login/status/usage/delete`，并接入命令解析、help 与 runner。`login` 会先用 usage 拉取校验 token，再写入通用 token store；Copilot 采用单账号覆盖语义。
- SDK 层 `CopilotUsageDescriptor` 已支持注入 `fetchUsage` 闭包，便于测试；同时输出具名 usage windows：`Chat`、`Premium`。
- App 层 Copilot template 已开放 `usage` vendor tab，但 `supportsAccounts` 继续保持 `false`，符合本轮产品边界；详情页 header action 对 Copilot 保留 `refresh`，若存在 dashboard sign-in 再补 `signIn`。
- 已完成定向验证：
  - `swift test --package-path libs/Providers --filter CopilotUsageDescriptorTests`
  - `swift test --package-path libs/Providers --filter NolonCoreCLIKitTests`
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexBinaryTabConfigurationTests -only-testing:nolonTests/ProviderUsageLoginFlowViewModelParityTests`
