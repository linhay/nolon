# Codex Advanced 配置保留现有 TOML 修复（2026-03-11）

## 背景
- 用户反馈：点击 Codex Provider 的 `高级配置` tab 后，现有 `config.toml` 配置会被移除。
- 根因有两层：
  1. `Advanced` 页面的结构化控件在初始化灌值时可能触发自动保存。
  2. 结构化保存使用 `CodexConfigToml + TOMLEncoder` 整文件重写，未建模字段、注释与用户自定义 section 会被裁剪。

## 范围
- 包含：
  - 阻止初始化阶段的自动保存。
  - 结构化保存改为增量 patch，仅修改 UI 覆盖的键。
  - 结构化草稿加载改为文本级提取，避免因未知 `[agents]` / role 字段导致整个配置解析失败。
- 不包含：
  - `Edit Raw TOML` 的行为变更。
  - `model` / `model_reasoning_effort` 的独立写入链路变更。

## BDD 验收
1. Given `config.toml` 含未知顶层键、注释或额外 section
   When 用户点击 `高级配置`
   Then 文件内容保持不变。

2. Given `config.toml` 含结构化 UI 未覆盖的 TOML 内容
   When 用户修改 `approval_policy`、`sandbox_mode`、`features.multi_agent` 或 role 配置并保存
   Then 只更新对应键，未知内容保留。

3. Given `[agents]` 或 `[agents.<role>]` 含未知字段
   When `Advanced` 页面加载
   Then 已知字段仍能提取到结构化草稿，不因整体解码失败而清空 UI。

## 实现摘要
- `CodexAdvancedConfigViewModel` 新增 hydration guard：
  - `isHydratingStructuredDraft`
  - `hasLoadedStructuredDraft`
  - `scheduleStructuredSaveIfReady()`
- `loadConfigDraft()` 改为从原始 TOML 文本提取结构化字段。
- `saveStructuredConfig()` 改为调用 `CodexStructuredConfigPatchService` 对原始文本做增量 patch。
- 顶层、`[features]`、`[agents]`、`[agents.<role>]` 的受控键单独 patch，其他内容原样保留。

## 验证
- `xcodebuild -project nolon.xcodeproj -scheme nolon-app -destination 'platform=macOS' test -only-testing:nolonTests/CodexAdvancedConfigRoleDraftTests`
- 新增回归覆盖：
  - 结构化 patch 保留未知 TOML
  - 初始化前不调度保存
  - 结构化保存后仍保留不受控内容

## 风险
- 受控 block 内部的原始键顺序与局部注释不保证完全保持。
- 文本提取器当前只覆盖 `Advanced` 页面支持的键；新字段需要同步扩展提取/patch 规则。
