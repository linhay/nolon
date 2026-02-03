---
description: providers-migration
---

# Workflow: providers-migration

用于将 App 内的厂商（Provider）相关“非 GUI 逻辑”下沉到 `libs/Providers`，并让 App 的 Provider 视图只消费 `libs/Providers` 输出的通用数据模型；同时确保 CLI/GUI/测试环境的 env/PATH 行为一致，并为 Providers 建立可运行的单测与（可选）live tests。

## 适用范围
- 本仓库：Nolon
- 典型场景：
  - `nolon/*` 内出现 provider 的解析/抓取/路径探测/配置定义/命令拼装等逻辑
  - Provider 账号/用量 UI 与参考实现（如 CodexBar）口径不一致
  - app/test 中提示 “CLI missing”，但终端可运行

## 输入
- 目标 provider（例如 Codex）
- 参考实现（可选）：`libs/CodexBar`（仅对齐行为/数据口径，不直接集成/依赖）
- 需要在 UI 展示的字段清单（例如：account/plan/session/weekly/credits/cost）

## 输出
- `libs/Providers/Sources/*`：新增/调整 provider 的配置定义、抓取实现、统一模型与 descriptor 输出
- `nolon/Skills/Views/Provider/*`：通用视图仅依赖 Providers 输出（不包含厂商特定抓取/解析）
- `libs/Providers/Tests/*`：`import Testing` 的单测；live tests 有开关并可跳过

## 步骤
1. **明确口径与字段**
   - 明确用量百分比口径：`xx% left`（remaining）还是 `xx% used`（used），并统一到 Providers 模型层；UI 只负责展示。
   - 明确需要字段：account、plan、credits、cost（today/last30）、tokens 等。

2. **下沉非 GUI 逻辑到 `libs/Providers`**
   - 将 provider 的配置来源（用户路径/配置文件）、解析、抓取、命令调用、错误映射等移动到 `libs/Providers/Sources`。
   - App 侧保留：视图布局、交互、展示状态（loading/error/empty）与本地化文本。

3. **统一数据模型与 descriptor**
   - 在 Providers 内定义稳定的“通用输出模型”（例如 `ProviderUsage`/`ProviderIdentity`/`ProviderCost` 等）。
   - 为每个 provider 提供一个 descriptor（或等价聚合层），负责并发拉取并合并：rate limits / account / cost / credits。

4. **修复共享 target 依赖与 module import**
   - 若出现 “Initializer ... missing import of defining module ...”：
     - 优先修复 target 依赖（shared target/feature target 是否链接到 `ProviderUsage` 等模块）
     - 同步补齐 `import`（仅当依赖已正确链接后仍需要）

5. **对齐 env/PATH（CLI/GUI/test 一致性）**
   - 外部 CLI（如 `codex`）必须通过 `SKProcessRunner` 运行，并合并 login shell 环境（尤其 PATH）。
   - 避免在 App 侧拼装“特殊 PATH”；把环境策略沉淀在 `SKProcessRunner` 或 Providers 层。

6. **建立测试（TDD + 可选 live）**
   - 单测（默认）：`import Testing`，用固定样本（fixture）覆盖解析与模型映射。
   - live tests（可选）：读取用户 env/配置；必须由环境变量开关启用（例如 `RUN_LIVE_PROVIDER_TESTS=1`），缺失必要 env 时应显式 skip。

## 验收
- Providers：`swift test --package-path libs/Providers` 通过（live tests 默认不跑）
- App：`./build.sh` 通过（或项目约定的 build 验证方式）
- UI：account/plan/credits/cost 等字段在 env 可用时可显示；用量百分比口径与参考实现一致

